namespace :stripe do

  desc "prints subscription billing date for all Users"
  task subscription_start_date: [:environment] do
    days_of_month = {}
    User.all.each do |user|
      #puts user.customer.stripe_customer
      start = nil 
      begin
        start = Time.at user.customer.stripe_subscription.start
      rescue => e
        puts e
      end 
      next unless start
      days_of_month[start.day] = 0 unless days_of_month[start.day]
      days_of_month[start.day] += 1
    end 
    pp days_of_month
  end

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

  desc "delete duplicates"
  task delete_dupes: [:environment] do
    # build hash of all Customers, email => customer_id, from Stripe, with no plan
    stripe_customers = {}
    # fetch first page to get total we expect
    custs = Stripe::Customer.all(limit: 100, include: ['total_count'])
    stripe_total = custs.total_count
    customer_offset = nil
    customer_count = 0
    custs.each do |cust|
      customer_count += 1
      if cust.subscriptions.count == 0
        stripe_customers[cust.email] = cust.id
      end
      customer_offset = cust.id
    end
    while customer_count < stripe_total
      custs = Stripe::Customer.all(limit: 100, include: ['total_count'], starting_after: customer_offset)
      custs.each do |cust|
        customer_count += 1
        if cust.subscriptions.count == 0
          stripe_customers[cust.email] = cust.id
        end
        customer_offset = cust.id
      end
      puts "Fetched #{customer_count} of #{stripe_total} Stripe customers; offset #{customer_offset}"
    end

    # compare against our Users
    stripe_customers.keys.each do |email|
      user = User.find_by_email(email) or next

      if user.customer_id != stripe_customers[email]

        # (optionally) delete non-existent Users from Stripe
        if ENV['DELETE_OK']
          c = Stripe::Customer.retrieve(stripe_customers[email])
          c.delete
        else
          puts "Should delete #{email} => #{stripe_customers[email]}"
        end
      end
    end

  end

  desc "populate charges table for all users"
  task populate_charges: [:environment] do
    User.find_in_batches do |users|
      users.each do |user|
        user.populate_charges
      end
    end
  end

end

