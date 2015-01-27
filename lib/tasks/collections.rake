namespace :collections do

  desc "clean up vestigal My Uploads"
  task clean_my_uploads: [:environment] do
    verbose = ENV['VERBOSE'] || false
    dry_run = ENV['DRY_RUN'] || false

    Collection.find_in_batches do |collgrp|
      collgrp.each do |coll|
        if coll.title == 'My Uploads'
          verbose and puts "Collection.find(#{coll.id})"
          if coll.items.size > 0
            verbose and puts "  has Items: #{coll.items.size.to_s}"
            # find another collection to re-assign items
            owner = coll.billable_to
            alt_coll = owner.collections.shift
            loops = 0
            while alt_coll && alt_coll.id == coll.id
              alt_coll = owner.collections.shift
              loops += 1
              break if loops > 10  # sanity
            end
            if !alt_coll
              puts "  >> Unable to identify alternate collection to inherit items"
              next
            end
            if !dry_run
              coll.items.each do |item|
                item.collection_id = alt_coll.id
                item.save!
              end 
            end
          end
          next if dry_run
          coll.destroy
        end
      end
    end
  end

end
