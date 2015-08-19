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
      if ENV['SEND_ALERTS'] && user.is_within_sight_of_monthly_limit? && !user.plan.is_community?
        user.send_usage_alert
      end
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
      if ENV['SEND_ALERTS'] && org.is_within_sight_of_monthly_limit? && !org.owner.plan.is_community?
        org.send_usage_alert
      end
      progress.inc
    end
    progress.finish
  end

  desc "All account usage reports"
  task usage: [:environment] do
    Rake::Task["reports:bill_collections"].invoke
    Rake::Task["reports:bill_collections"].reenable
    Rake::Task["reports:calculate_users_monthly"].invoke
    Rake::Task["reports:calculate_users_monthly"].reenable
    Rake::Task["reports:calculate_orgs_monthly"].invoke
    Rake::Task["reports:calculate_orgs_monthly"].reenable
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

  desc "prints non-zero premium usage for a given month, for customers on basic plans"
  task ondemand_billing: [:environment] do
    now = DateTime.now
    yearmonth = ENV['MONTH'] || sprintf("%d-%02d", now.year, now.month)
    puts "Generating report for basic-plan customers with on-demand charges for #{yearmonth}..."
    puts '='*100
    recs = MonthlyUsage.where(:yearmonth => yearmonth).where(:use => MonthlyUsage::PREMIUM_TRANSCRIPTS).where('value > 0')
    num = 0
    printf("%6s %12s %40s  %s      %s\n", 'ID', 'Type', 'Name', 'Time', 'Cost')
    puts '-'*100
    recs.find_each do |mu|
      if !mu.entity
        puts "No entity defined for #{mu.inspect}"
        next
      end
      if !mu.entity.plan.has_premium_transcripts?
        printf("%6d %12s %40s  %s  $%0.2f\n", mu.entity_id, mu.entity_type, mu.entity.name, mu.value_as_hms, mu.retail_cost)
        num += 1
      end
    end
    puts '='*100
    puts "Total: #{num}" 
  end

  desc "prints subscriber sign-up summary for the current month"
  task customer_sign_ups: [:environment] do

    # optional to send report via email
    send_mail = ENV['SEND_MAIL'] || false

    # find all the Users created this month
    now = ENV['FOR_MONTH'] ? DateTime.parse(ENV['FOR_MONTH']) : DateTime.now
    the_month = now.utc.strftime('%Y-%m')
    users = User.created_in_month(now)

    # set up report
    buf = []
    buf.push "PUA New Customer Report for #{now.strftime('%Y-%m')}\n"
    buf.push '-'*80, "\n"
    buf.push "Date       ID                    Name             Plan  Prorated  #{the_month} Hours\n"
    buf.push '-'*80, "\n" 
    users.each do |user|
      #next if user.plan.is_community?
      dt = user.created_at.strftime('%Y-%m-%d')
      usage = 0
      user.monthly_usages.select {|mu| mu.yearmonth == the_month}.each do |mu|
        usage += mu.value
      end
      line = sprintf("%s %s %21s %10s %4s   $%8.2f    %s\n", dt, user.id, user.name.slice(0,20), user.plan.name, user.pop_up_hours, user.prorated_charge_for_month(now), Api::BaseHelper::time_definition(usage))
      buf.push line
    end
    if send_mail
      MyMailer.mailto('PUA New Customer Report', buf.join('')).deliver
    else
      puts buf.join('')
    end
  end

  desc "prints customer subscription changes for a given month"
  task customer_subscription_events: [:environment] do

    # optional to send report via email
    send_mail = ENV['SEND_MAIL'] || false

    # find all the Comments created this month
    now = ENV['FOR_MONTH'] ? DateTime.parse(ENV['FOR_MONTH']) : DateTime.now
    the_month = now.utc.strftime('%Y-%m')
    comments = ActiveAdminComment.created_in_month(now, 'stripe')

    # set up report
    buf = []
    buf.push "PUA Customer Subscription Event Report for #{now.strftime('%Y-%m')}\n"
    buf.push '-'*90, "\n"
    buf.push sprintf("%10s %4s %21s %25s  %25s\n", 'Date', 'ID', 'Name', 'Old Plan', 'New Plan')
    buf.push '-'*90, "\n" 
    comments.each do |comment|
      #puts '='*80
      dt = comment.created_at.strftime('%Y-%m-%d')
      event = JSON.parse(comment.body)
      #pp event
      chg = event['data']['previous_attributes']
      #puts '-'*40
      #pp chg
      next unless chg

      # we only care about plan changes
      next unless chg.has_key? 'plan'

      # new plan vs old plan
      old_plan = chg['plan']['id']
      user = comment.resource
      line = sprintf("%10s %4s %21s %25s  %25s\n", dt, user.id, user.name.slice(0,20), old_plan, user.plan.id)
      buf.push line
    end 
    if send_mail && buf.size > 0
      MyMailer.mailto('PUA Customer Subscription Event Report', buf.join('')).deliver
    else
      puts buf.join('')
    end

  end

end
