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

  desc "identify (and optionally cleanup) duplicate items"
  task check_dupes: [:environment] do
    verbose = ENV['VERBOSE'] || false
    dry_run = ENV['DRY_RUN'] || false

    # ugh. hardcoded list ugly. would be nice if collection had some meta on it.
    coll_ids_from_feed = [
      438,
      799,
      676,
      800,
      801,
      810,
      810,
      1573,
      1574,
      1575,
      1586,
      1587,
      1588,
      1654,
      1596,
      1705,
      1633,
      1653,
      1655,
      1656,
      1657,
      1686,
      1687,
      1703,
      1754,
      1780,
      1781,
      1782,
      1785,
      1868,
      1928,
      1975,
      2082,
      2088,
      2064,
      2594,
      3246,
      3247,
      3653,
      3722,
      3758,
      1673,
      4239,
      3626,
      4258,
      4261,
      4262,
      4263,
      4264,
      4265,
      4266,
      2347
    ]
    colls_from_feed = Hash[coll_ids_from_feed.map{|i| [i, 1]}]
    by_title = {}
    deleted = {}
    Item.find_in_batches do |itemgrp|
      itemgrp.each do |item|
        next unless colls_from_feed.has_key?(item.collection_id)
        k = item.title + ':' + item.collection_id.to_s + ':' + item.date_broadcast.to_s
        if by_title.has_key?(k)
          by_title[k][:count] += 1
          by_title[k][:ids].push item.id
        else
          by_title[k] = { :count => 1, :ids => [ item.id ] }
        end
      end
    end

    by_title.each do |key, value|
      next unless value[:count] > 1
      verbose and puts "Dupe: #{key} #{value.inspect}"

      # keep (the first) with premium transcript
      keeper = nil
      value[:ids].each do |item_id|
        next if keeper
        item = Item.find item_id
        has_premium = false
        item.audio_files.each do |af|
          af.transcripts_alone.each do |t|
            if t.is_premium?
              has_premium = true
            end
          end
        end
        keeper = item_id if has_premium
      end

      # no keeper? keep the first one
      keeper ||= value[:ids].shift

      verbose and puts "  keep #{keeper}"
      next if dry_run
      
      # for others, flag all transcripts as not billable,
      # and then soft-delete the item
      value[:ids].each do |item_id|
        next if item_id == keeper
        item = Item.find item_id
        item.transcripts.each do |tr|
          tr.is_billable = false
          tr.save!
        end
        item.destroy
        deleted[item.id] = true
      end

    end

    verbose and puts "deleted #{deleted.keys.count} Items"

  end

end
