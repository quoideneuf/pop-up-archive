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

end
