require 'ansi/progressbar'

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

  desc "All account usage reports: incremental"
  task usage_increm: [:environment] do
    Rake::Task["reports:user_usage_increm"].invoke
    Rake::Task["reports:user_usage_increm"].reenable
    Rake::Task["reports:org_usage_increm"].invoke
    Rake::Task["reports:org_usage_increm"].reenable
  end

  desc "User account usage reports: incremental (set SINCE)"
  task user_usage_increm: [:environment] do
    user_ids = User.get_user_ids_for_transcripts_since(ENV['SINCE'])
    progress = ANSI::Progressbar.new("#{user_ids.size} Users", user_ids.size, STDOUT)
    progress.bar_mark = '='
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
    progress = ANSI::Progressbar.new("#{org_ids.size} Orgs", org_ids.size, STDOUT)
    progress.bar_mark = '='
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

  desc "recalculate monthly usage"
  task recalculate_monthly: [:environment] do
    nusers = User.count
    progress = ANSI::Progressbar.new("#{nusers} Users", nusers, STDOUT)
    progress.bar_mark = '='
    User.find_each do |user|
      # get array of date objects, one for each first-day-of-month since the User was created.
      months = (DateTime.parse(user.created_at.to_s)<<1 .. DateTime.now).select{ |d| d.strftime("%Y-%m-01") if d.day.to_i == 1 }
      months.each do |dtim|
        ucalc = UsageCalculator.new(user, dtim)
        ucalc.calculate(Tasks::TranscribeTask, MonthlyUsage::BASIC_TRANSCRIPTS)
        ucalc.calculate(Tasks::SpeechmaticsTranscribeTask, MonthlyUsage::PREMIUM_TRANSCRIPTS)
      end
      progress.inc
    end 
    progress.finish
  end

end
