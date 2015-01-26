namespace :items do

  desc "align Item.is_public with parent Collection"
  task check_public: [:environment] do
    verbose = ENV['VERBOSE'] || false
    dry_run = ENV['DRY_RUN'] || false

    Item.find_in_batches do |itemgrp|
      itemgrp.each do |item|
        if item.is_public != item.collection.items_visible_by_default
          verbose and puts "Item.find(#{item.id}) is_public mismatch"
          next if dry_run
          item.is_public = item.collection.items_visible_by_default
          item.save!
        end
      end
    end
  end

end
