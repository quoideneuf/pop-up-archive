namespace :subscriptions do

  desc "Cache and display all Stripe subscription plans"
  task cache_all: [:environment] do
    plans = SubscriptionPlanCached.all
    cnt = 0
    plans.each do |plan|
      puts "plan #{cnt}"
      puts pp plan
      cnt += 1
    end
  end

  desc "migrate existing Community users to Premium Community"
  task migrate_community: [:environment] do
    comm_plan = SubscriptionPlanCached.basic_community.as_plan
    prem_plan = SubscriptionPlanCached.community
    User.find_in_batches do |users|
      users.each do |user|
        next if user.subscription_plan_id != comm_plan.id
        user.subscribe!(prem_plan)
      end
    end
  end

end
