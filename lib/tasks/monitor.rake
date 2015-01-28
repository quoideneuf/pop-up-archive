namespace :monitor do
  desc "updating feeds"
  task :feed, [:url, :collection_id] => [:environment] do |t, args|
    puts "Scheduling new feed check: "+args.url
    if ENV['NOW']
      FeedPopUp.update_from_feed(args.url, args.collection_id, ENV['DRY_RUN'], ENV['OLDEST_ENTRY'])
    else
      FeedUpdateWorker.perform_async(args.url, args.collection_id, ENV['OLDEST_ENTRY'])
    end
    puts "done."
  end
end
