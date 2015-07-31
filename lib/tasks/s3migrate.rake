require 'pp'

namespace :s3migrate do

  desc "compare PRX and PUA buckets"
  task :compare_buckets => [:environment] do
    compare_buckets(ENV['OK_TO_COPY'])
  end

  desc "Copy all Items from PRX S3 bucket to PUA bucket"
  task :all_items => [:environment] do
    verbose = ENV['VERBOSE']
    Item.find_in_batches do |items|
      items.each do |item|
        next if item.storage.key == ENV['AWS_ACCESS_KEY_ID']
        copy_item(item)
      end
    end
  end

  desc "Copy all Collection images from PRX S3 bucket to PUA bucket"
  task :all_collection_images => [:environment] do
    verbose = ENV['VERBOSE']
    Collection.find_in_batches do |colls|
      colls.each do |coll|
        coll.image_files.each do |imgf|
          next if imgf.storage.key == ENV['AWS_ACCESS_KEY_ID']
          # NOTE this will copy multiple images in one go,
          # but we want to update storage config for all of them,
          # so since the assets are small, just re-copy each time.
          # edge case.
          if copy_bucket_dir(coll.token, imgf.storage.bucket, verbose)
            puts "Copy ImageFile #{imgf.id} ok"
            storage        = imgf.storage
            storage.key    = ENV['AWS_ACCESS_KEY_ID']
            storage.secret = ENV['AWS_SECRET_ACCESS_KEY']
            storage.bucket = ENV['AWS_BUCKET']
            storage.save!
          else
            puts "Copy ImageFile #{imgf.id} failed"
          end
        end
      end
    end
  end

  desc "Copy all Collections"
  task :all_collections => [:environment] do
    verbose = ENV['VERBOSE']
    Collection.find_in_batches do |colls|
      colls.each do |coll|
        copy_bucket_dir(coll.token, 'pop-up-archive', verbose)
      end
    end
  end

  desc "Copy single Item contents from PRX S3 bucket to PUA bucket"
  task :item, [:item_id] => [:environment] do |t, args|
    verbose = ENV['VERBOSE']
    item = Item.find(args.item_id.to_i)
    copy_item(item, ENV['FORCE'] ? false : true )
  end

  desc "Copy single Collection contents"
  task :collection, [:coll_id] => [:environment] do |t, args|
    verbose = ENV['VERBOSE']
    collection = Collection.find(args.coll_id.to_i)
    copy_bucket_dir(collection.token, 'pop-up-archive', verbose)
  end

  def copy_item(item, strict=true)
    verbose = ENV['VERBOSE']
    if strict and item.storage.key == ENV['AWS_ACCESS_KEY_ID']
      raise "Item #{item.id} already configured to use PUA storage"
    elsif !strict and item.storage.bucket == ENV['AWS_BUCKET']
      item.storage.bucket = 'pop-up-archive' # temp override
    end 
    if copy_bucket_dir(item.token, item.storage.bucket, verbose)
      puts "Copy for item #{item.id} ok"
      # update storage config
      storage        = item.storage
      storage.key    = ENV['AWS_ACCESS_KEY_ID']
      storage.secret = ENV['AWS_SECRET_ACCESS_KEY']
      storage.bucket = ENV['AWS_BUCKET']
      storage.save!
    else
      puts "Copy for item #{item.id} failed"
    end
  end

  # assumes 'aws' command is configured with appropriate credentials and profile names
  # uploads.popuparchive.com is configured correctly.
  def copy_bucket_dir(token, old_bucket, verbose=false)
    new_bucket = ENV['AWS_BUCKET']
    # get contents of old bucket dir
    cmd = "aws s3 ls --recursive --profile prx s3://#{old_bucket}/#{token}/"
    verbose and puts cmd
    contents = %x( #{cmd} ).split(/$/).map(&:strip)
    dir_contents = {}
    contents.each do |line|
      ls_line = line.split
      next unless ls_line[3]
      # filename => size
      dir_contents[ ls_line[3] ] = ls_line[2]
    end
    verbose and pp dir_contents

    # copy them locally
    tmpdir   = "/tmp/s3-migrate/#{token}/"
    system("mkdir -p #{tmpdir}") or raise "Failed to create tmpdir #{tmpdir}: #{$?}"
    cp_cmd = "aws s3 --profile prx cp --recursive s3://#{old_bucket}/#{token}/ #{tmpdir}"
    verbose and puts cp_cmd
    system(cp_cmd) or raise "#{cp_cmd} failed: #{$?}"

    # create new bucket dir and sync
    sync_cmd = "aws s3 --profile pua sync #{tmpdir} s3://#{new_bucket}/#{token}/"
    verbose and puts sync_cmd
    system(sync_cmd) or raise "#{sync_cmd} failed: #{$?}"

    # verify everything copied ok
    ls_cmd = "aws s3 ls --recursive --profile pua s3://#{new_bucket}/#{token}/"
    verbose and puts ls_cmd
    new_contents = %x( #{ls_cmd} ).split(/$/).map(&:strip)
    new_dir_contents = {}
    new_contents.each do |line|
      ls_line = line.split
      next unless ls_line[3]
      new_dir_contents[ ls_line[3] ] = ls_line[2]
    end
    verbose and pp new_dir_contents

    # return value is whether contents are equal
    copy_ok = dir_contents == new_dir_contents
    
    # clean up
    if copy_ok
      system("rm -rf #{tmpdir}") or raise "Failed to clean up tmpdir #{tmpdir}: #{$?}"
    end

    copy_ok
  end

  def build_bucket_list(profile, bucket)
    verbose = ENV['VERBOSE']
    lscmd = "aws s3 ls --recursive --profile #{profile} s3://#{bucket}/"
    files = %x( #{lscmd} ).split(/$/).map(&:strip)
    list  = {}
    files.each do |fline|
      flines = fline.split
      next unless flines[3]
      list[ flines[3] ] = flines[2]
    end
    verbose and pp list
    list
  end

  def compare_buckets(ok_to_copy=false)
    prx_bucket = 'pop-up-archive'
    pua_bucket = 'www-prod-popuparchive'
    prx_list = build_bucket_list('prx', prx_bucket)
    pua_list = build_bucket_list('pua', pua_bucket)

    # we expect the union of the 2 sets to represent all the assets
    # copied from prx -> pua. if there are any items @ prx that are
    # not @ pua, and they are not soft-deleted in the db, then we have a problem.
    union_keys = prx_list.keys & pua_list.keys
    seen_tokens = {}

    # allow for running in parallel
    start_at = ENV["START_AT"]
    prx_list.keys.each do |prx_file|
      next if union_keys.include?(prx_file) # skip union

      if start_at and prx_file[0,1].downcase < start_at.downcase
        next
      end
      
      # parse string to get token and look up Item
      parts = prx_file.match(/^(.+?)\//)
      unless parts
        puts "No parts match for '#{prx_file}'"
        next
      end
      token = parts[1]
      next if seen_tokens[token]
      seen_tokens[token] = true
      item = Item.where(token: token).first
      collection = Collection.where(token: token).first
      next unless (item or collection) # must be deleted
      next unless ok_to_copy
      if item
        puts "Missing Item #{item.id} contents at PUA: #{prx_file}"
        item.storage.bucket = prx_bucket # force to be old bucket temporarily
        copy_item(item, false)  # turn off strict check
      elsif collection
        puts "Missing Collection #{collection.id} contents at PUA: #{prx_file}"
        copy_bucket_dir(collection.token, prx_bucket, true)
      end
    end

  end

end
