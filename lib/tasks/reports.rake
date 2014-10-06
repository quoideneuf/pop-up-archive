namespace :reports do

  desc "User account usage reports"
  task user_usage: [:environment] do
    progress = ANSI::Progressbar.new("Users", User.count, STDOUT)
    progress.bar_mark = '='
    User.find_each do |user|
      user.update_usage_report!
      progress.inc
    end
    progress.finish
  end

  desc "Organization account usage reports"
  task org_usage: [:environment] do
    progress = ANSI::Progressbar.new("Orgs", Organization.count, STDOUT) 
    progress.bar_mark = '='
    Organization.find_each do |org|
      org.update_usage_report!
      progress.inc
    end
    progress.finish
  end

  desc "All account usage reports"
  task usage: [:environment] do
    Rake::Task["reports:user_usage"].invoke
    Rake::Task["reports:user_usage"].reenable
    Rake::Task["reports:org_usage"].invoke
    Rake::Task["reports:org_usage"].reenable
  end

  desc "audio files most played"
  task play_count: [:environment] do
    afs = AudioFile.order('listens desc').limit(25).includes(:item)
    afs_important_attrs = afs.map{|a| [a.listens, a.item.title, a.item.collection.title, a.item.url] }
    array = [["Listens", "ItemTitle", "Collection Title", "URL"], *afs_important_attrs]
    File.open('tmp/most_played' + Time.now.strftime("%m%d%Y") + '.yml', 'w') {|f| f.write(array) }    
    puts array.to_table  
  end   
end
