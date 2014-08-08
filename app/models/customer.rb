class Customer
  attr_reader :id, :plan_id, :card, :trial, :interval

  def initialize(stripe_customer)
    @id = stripe_customer.id
    if stripe_customer.respond_to?(:subscription) && stripe_customer.subscription.present?
      @plan_id = stripe_customer.subscription.plan.id
      if stripe_customer.subscription.trial_end.present?
        @trial = (Time.at(stripe_customer.subscription.trial_end).to_date - Date.today).to_i
      else
        @trial = 0
      end
    end
    @card = stripe_customer.respond_to?(:cards) ? stripe_customer.cards.data[0].as_json.try(:slice, *%w(last4 type exp_month exp_year)) : {}
  end

  def plan
    SubscriptionPlan.find(plan_id) || subscribe_to_community
  end

  def eql?(customer)
    customer.id == id
  end

  def stripe_customer
    Stripe::Customer.retrieve(id)
  end

  alias :eql? :==

  def subscribe_to_community
    stripe_customer.update_subscription(plan: SubscriptionPlan.community.id)
    Rails.cache.delete([:customer, :individual, id])
    SubscriptionPlan.community
  end
end
