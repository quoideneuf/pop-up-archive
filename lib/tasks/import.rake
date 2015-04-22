require 'pb_core'

namespace :import do

  desc "Import PBCore 2.0 pbcoreDescriptionDocument XML file from Omeka"
  task :pbcore_omeka_doc, [:collection_id, :file] => [:environment] do |t, args|
    importer = PBCoreImporter.new(collection_id: args.collection_id, file: args.file)
    importer.import_omeka_description_document
  end


  desc "Import PBCore 2.0 pbcoreCollection XML file from Omeka"
  task :pbcore_omeka_collection, [:collection_id, :file] => [:environment] do |t, args|
    importer = PBCoreImporter.new(collection_id: args.collection_id, file: args.file)
    importer.import_omeka_collection
  end

desc "Import PBCore 2.0 pbcoreCollection XML file from a URL"
  task :pbcore_url_collection, [:collection_id, :url] => [:environment] do |t, args|
    importer = PBCoreImporter.new(collection_id: args.collection_id, url: args.url, verbose: ENV['VERBOSE'])
    importer.import_omeka_collection
  end
  
  desc "Import Open Vault xml files from a directory"
  task :xml_openvault_collection, [:collection_id, :dir] => [:environment] do |t, args|
    importer = XMLMediaImporter.new(collection_id: args.collection_id, dir: args.dir)
    importer.import_openvault_directory
  end

  desc "Import Illinois Collection XML file"
  task :xml_illinois_collection, [:collection_id, :file, :first_item, :last_item] => [:environment] do |t, args|
    importer = XMLMediaImporter.new(collection_id: args.collection_id, file: args.file, first_item: args.first_item, last_item: args.last_item)
    importer.import_xml_illinois_collection
  end

  desc "Import BBG Collection XML file "
  task :xml_bbg_collection, [:collection_id, :file] => [:environment] do |t, args|
    importer = XMLMediaImporter.new(collection_id: args.collection_id, file: args.file)
    importer.import_xml_bbg_feed
  end

  desc "Import Kitchen Sisters XML file by filtering urls"
  task :xml_ks_collection_filter, [:collection_id, :file, :filter, :first_item, :last_item] => [:environment] do |t, args|
    importer = XMLMediaImporter.new(collection_id: args.collection_id, file: args.file, filter: args.filter, first_item: args.first_item, last_item:args.last_item)
    importer.filter_ks_xml_file
  end

  desc "Import FTP folder"
  task :ftp_folder, [:collection_id, :url, :folder, :user, :password, :first_item, :last_item] => [:environment] do |t, args|
    importer = RemoteImporter.new(collection_id: args.collection_id, url: args.url, folder: args.folder, user: args.user, password: args.password, first_item: args.first_item, last_item: args.last_item )
    importer.get_ftp_folder
  end

  desc "Reconcile existing data with a feed, populating the Item.identifier"
  task :reconcile_feed, [:collection_id, :url] => [:environment] do |t, args|
    # load the feed
    able_to_parse = true
    collection = Collection.find(args.collection_id)
    feed = Feedjira::Feed.fetch_and_parse(args.url, :on_failure => lambda {|url, response_code, header, body| able_to_parse = false if response_code == 200 })
 
    if !able_to_parse || !feed.entries || feed.entries.size == 0 
      puts "Bad feed or no entries found: #{url}"
      return
    end

    # look for existing items
    feed.entries.each do |entry|
      #puts "#{entry.inspect}"
      uri = entry.enclosure_url.to_s
      next if Item.where(identifier: uri, collection_id: collection.id).exists?
      
      # search by title
      title = entry.title.to_s
      item = Item.where(title: title, collection_id: collection.id).last
      if item
        item.identifier = uri
        item.save!
        next
      end

      # search by audio filename
      filename = File.basename(URI(uri).path)
      puts "filename==#{filename}"
      afs = AudioFile.where(file: filename)
      if afs.count == 1
        puts "Found possible AudioFile #{afs.first.id} : #{afs.first.item.inspect}"
        af = afs.first
        if af.item.collection_id == collection.id
          af.item.identifier = uri
          af.item.save!
          next
        end
      else
        afs.each do |af|
          puts "Possible audiofile match: #{af.file}"
        end
      end

      # search by date
      pubdate = DateTime.parse(entry.published.to_s).utc
      items = Item.where(date_broadcast: pubdate.to_date.iso8601, collection_id: collection.id)
      if items.count == 1
        item = items.first
        item.identifier = uri
        item.save!
        next
      end

      # too many possibilities, so just warn
      items.each do |item|
        puts "Possible item #{item.id} : >>#{item.title}<< for >>#{title}<<"
      end

      puts "Failed to find item: #{pubdate} #{title} #{uri}"
      puts '=' * 80
    end

  end
end
