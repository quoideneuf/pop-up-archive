require 'ansi/progressbar'

namespace :reports do

  desc "Check all Collections are billable"
  task bill_collections: [:environment] do
    ncolls = Collection.count
    puts "Check Collections are billable"
    progress = ANSI::Progressbar.new("#{ncolls} Colls", ncolls, STDOUT)
    progress.bar_mark = '=' 
    progress.style(:title => [:blue], :bar=>[:blue])
    progress.send(:show)
    Collection.find_in_batches do |cgroup|
      cgroup.each do |coll|
        coll.check_billable_to!
        progress.inc
      end 
    end
    progress.finish
  end

  desc "User account usage reports"
  task user_usage: [:environment] do
    nusers = User.count
    puts "User Usage Totals"
    progress = ANSI::Progressbar.new("#{nusers} Users", nusers, STDOUT)
    progress.bar_mark = '='
    progress.style(:title => [:blue], :bar=>[:blue])
    progress.send(:show)
    User.find_each do |user|
      user.update_usage_report!
      progress.inc
    end
    progress.finish
  end

  desc "Organization account usage reports"
  task org_usage: [:environment] do
    norgs = Organization.count
    puts "Organization Usage Totals"
    progress = ANSI::Progressbar.new("#{norgs} Orgs", norgs, STDOUT) 
    progress.bar_mark = '='
    progress.style(:title => [:blue], :bar=>[:blue])
    progress.send(:show)
    Organization.find_each do |org|
      org.update_usage_report!
      progress.inc
    end
    progress.finish
  end

  desc "All account usage reports"
  task usage: [:environment] do
    Rake::Task["reports:calculate_users_monthly"].invoke
    Rake::Task["reports:calculate_orgs_monthly"].invoke
    Rake::Task["reports:user_usage"].invoke
    Rake::Task["reports:user_usage"].reenable
    Rake::Task["reports:org_usage"].invoke
    Rake::Task["reports:org_usage"].reenable
  end

  desc "All account usage reports: incremental"
  task usage_increm: [:environment] do
    # incremental assumes tasks are updating usage as they finish
    # so we only need to update totals.
    Rake::Task["reports:user_usage_increm"].invoke
    Rake::Task["reports:user_usage_increm"].reenable
    Rake::Task["reports:org_usage_increm"].invoke
    Rake::Task["reports:org_usage_increm"].reenable
  end

  desc "User account usage reports: incremental (set SINCE)"
  task user_usage_increm: [:environment] do
    user_ids = User.get_user_ids_for_transcripts_since(ENV['SINCE'])
    puts "Incremental User usage"
    progress = ANSI::Progressbar.new("#{user_ids.size} Users", user_ids.size, STDOUT)
    progress.bar_mark = '='
    progress.style(:title => [:blue], :bar=>[:blue])
    progress.send(:show)
    user_ids.each do|uid|
      user = User.find(uid)
      user.update_usage_report!
      progress.inc
    end
    progress.finish
  end

  desc "Organization account usage reports: incremental (set SINCE)"
  task org_usage_increm: [:environment] do
    org_ids = Organization.get_org_ids_for_transcripts_since(ENV['SINCE'])
    puts "Incremental Organization usage"
    progress = ANSI::Progressbar.new("#{org_ids.size} Orgs", org_ids.size, STDOUT)
    progress.bar_mark = '='
    progress.style(:title => [:blue], :bar=>[:blue])
    progress.send(:show)
    org_ids.each do|oid|
      org = Organization.find(oid)
      org.update_usage_report!
      progress.inc
    end
    progress.finish
  end

  desc "audio files most played"
  task play_count: [:environment] do
    afs = AudioFile.order('listens desc').limit(25).includes(:item)
    afs_important_attrs = afs.map{|a| [a.listens, a.item.title, a.item.collection.title, a.item.url] }
    array = [["Listens", "ItemTitle", "Collection Title", "URL"], *afs_important_attrs]
    File.open('tmp/most_played' + Time.now.strftime("%m%d%Y") + '.yml', 'w') {|f| f.write(array) }    
    puts array.to_table  
  end

  desc "calculate User monthly usage"
  task calculate_users_monthly: [:environment] do
    nusers = User.count
    puts "Monthly User usage"
    progress = ANSI::Progressbar.new("#{nusers} Users", nusers, STDOUT)
    progress.bar_mark = '='
    progress.style(:title => [:blue], :bar=>[:blue])
    progress.send(:show)
    User.find_each do |user|
      user.calculate_monthly_usages!
      progress.inc
    end 
    progress.finish
  end

  desc "calculate Organization monthly usage"
  task calculate_orgs_monthly: [:environment] do
    norgs = Organization.count
    puts "Monthly Organization usage"
    progress = ANSI::Progressbar.new("#{norgs} Orgs", norgs, STDOUT)
    progress.bar_mark = '='
    progress.style(:title => [:blue], :bar=>[:blue])
    progress.send(:show)
    Organization.find_each do |org|
      org.calculate_monthly_usages!

      # do non-billable usage for all users in the org too
      org.users.each do |user|
        user.calculate_monthly_usages!
      end

      progress.inc
    end 
    progress.finish
  end

end
