require 'digest/sha1'
require 'pp'

# rake environment elasticsearch:import:model CLASS=Item

namespace :search do
  desc 're-index all items'
  task index: [:environment] do
    if ENV['DEBUG']
      errs = Item.__elasticsearch__.import :return => 'errors'
      if errs.size
        STDERR.puts "ERRORS: "
        STDERR.puts pp(errs)
      end
    else 
      ENV['CLASS'] = 'Item'
      Rake::Task["elasticsearch:import:model"].invoke
      Rake::Task["elasticsearch:import:model"].reenable
    end
  end

  desc 're-index all items, in parallel'
  task mindex: [:environment] do
    nprocs     = ENV['NPROCS'] || 1
    batch_size = ENV['BATCH']  || 100
    max        = ENV['MAX']    || nil
    nprocs     = nprocs.to_i
    batch_size = batch_size.to_i

    # if asked to run on multiple CPUs,
    # calculate array of offsets based on nprocs
    if nprocs > 1
      pool_size = (Item.count / nprocs).round
      offsets = []

      # get all ids since we can't assume there are no holes in the PK sequencing
      # because of the deleted_at paranoia feature.
      ids = Item.order('id ASC').pluck(:id)
      ids.each_slice(pool_size) do |chunk|
        #puts "chunk: size=#{chunk.size} #{chunk.first}..#{chunk.last}"
        offsets.push( chunk.first )
      end
      puts "nprocs=#{nprocs} pool_size=#{pool_size} offsets=#{offsets} "

      offsets.each do |start_at|
        ActiveRecord::Base.connection.disconnect! # IMPORTANT before fork
        fork do
          # child worker
          # IMPORTANT after fork
          ActiveRecord::Base.establish_connection(ENV['DATABASE_URL'])

          completed = 0
          errors    = []
          puts "Start worker #{$$} at offset #{start_at}"
          pbar = ANSI::Progressbar.new("Item [#{$$}]", pool_size) rescue nil
          if pbar
            pbar.__send__ :show 
            pbar.bar_mark = '='
          end

          Item.__elasticsearch__.import :return => 'errors', :start => start_at, 
              :batch_size => batch_size    do |resp|
                # show errors immediately (rather than buffering them)
                errors += resp['items'].select { |k, v| k.values.first['error'] }
                completed += resp['items'].size
                pbar.inc resp['items'].size if pbar
                STDERR.flush
                STDOUT.flush
                if errors.size > 0
                  STDERR.puts "ERRORS in #{$$}:"
                  STDERR.puts pp(errors)
                end
                if completed >= pool_size || (max && max.to_i == completed)
                  pbar.finish if pbar
                  puts "Worker #{$$} finished #{completed} records"
                  exit # exit child worker
                end
              end 
          # end Item callback
        end
      end 
      Process.waitall

    else
      # otherwise just run as usual
      Rake::Task["search:index"].invoke
      Rake::Task["search:index"].reenable
    end
  end
      
      

  desc 'stage a reindex of all items'
  task stage: [:environment] do
    abort("TODO re-write to use elasticsearch tasks")
    Tire.index('items_ip').delete
    Tire.index(items_index_name) do
      add_alias 'items_ip'
      create mappings: Item.tire.mapping_to_hash
      import_all_items self
      remove_alias 'items_ip'
      Tire.index('items_st') do
        remove_alias 'items_st'
        delete
      end
      add_alias 'items_st'
      puts "finshed generating staging index #{name}"
    end
  end

  desc 'commit the staged index to be the new index'
  task :commit do
    abort("TODO re-write to use elasticsearch tasks")
    Tire.index('items').remove_alias('items')
    Tire.index 'items_st' do
      add_alias 'items'
      remove_alias 'items_st'
    end
    puts "promoted staging to items"
  end


  def items_index_name
    "items-rebuild-#{Digest::SHA1.hexdigest(Time.now.to_s)[0,8]}"
  end

  def set_up_progress
    print '|' + ' ' * 100 + '|' + '     '
    $stdout.flush
  end

  def progress(amount)
    print "\b" * 107
    print '|' + '#' * amount + ' ' * (100 - amount) + '| '
    print ' ' if amount < 10
    print ' ' if amount < 100
    print amount
    print '%'
    $stdout.flush
  end

  def import_all_items(index)
    count = Item.count
    done = 0
    set_up_progress
    Item.includes(:collection, :hosts, :creators, :interviewers, :interviewees, :producers, :geolocation, :contributors, :guests, :confirmed_entities, :low_scoring_entities, :middle_scoring_entities, :high_scoring_entities).includes(audio_files: :transcripts).find_in_batches batch_size: 10 do |items|
      index.import items
      done += items.size
      progress done * 100 / count
    end
    puts
  end
end
