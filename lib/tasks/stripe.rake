namespace :stripe do

  desc "set subscription_start_day"
  task set_subscription_start_day: [:environment] do
    User.all.each do |user|
      start = nil 
      subscr = nil 
      begin
        subscr = user.customer.stripe_subscription
        start = Time.at( subscr.current_period_end + 1 ).to_datetime.utc 
      rescue => e
        puts e
      end 
      next unless start
      user.subscription_start_day = start.day
      user.save!
    end
  end

  desc "change billing date to first of the month"
  task change_billing_date: [:environment] do
    # what days do we care about
    days = ENV['DAYS'].split(/,/)
    eom  = Customer.end_of_this_month
    User.where(subscription_start_day: days).each do |user|
      puts "Move user #{user.id} #{user.email} #{user.customer_id} #{user.plan.name} from #{user.subscription_start_day}"
      subscr = nil
      begin
        subscr = user.customer.stripe_subscription
      rescue => e
        puts e
      end
      subscr.trial_end = eom
      subscr.prorate   = false
      subscr.metadata[:moved_to_first] = Time.now.utc.to_i
      subscr.metadata[:updated]        = Time.now.utc.to_i
      subscr.save

    end
  end

end

