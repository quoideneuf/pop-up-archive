class Customer
  attr_reader :id, :plan_id, :card, :trial, :interval

  def initialize(stripe_customer=nil, *attrs)
    if !stripe_customer.nil?
      @id = stripe_customer.id
      subscr = stripe_subscription(stripe_customer)
      if subscr
        @plan_id = subscr.plan.id
        if subscr.trial_end.present?
          @trial = (Time.at(subscr.trial_end).to_date - Date.today).to_i
        else
          @trial = 0
        end
      end
      @card = stripe_customer.respond_to?(:cards) ? stripe_customer.cards.data[0].as_json.try(:slice, *%w(last4 type exp_month exp_year)) : {}
    else
      hashref = attrs.is_a?(Array) ? attrs.first : attrs
      @id = hashref[:id]
      @card = hashref[:card] || {}
      @plan_id = hashref[:plan_id]
      @trial = hashref[:trial] || 0
      @interval = hashref[:interval]
    end
  end

  def in_first_month?
  # another way of saying, was subscription initiated last month?
  # since the first interval is a 'trial' status.
    cust = stripe_customer
    if cust.nil?
      return nil
    end
    subscr = stripe_subscription(cust)
    #STDERR.puts "  subscription.meta==#{subscr.metadata.inspect}"
    #STDERR.puts "start_of_this_month==#{self.class.start_of_this_month.to_s}"
    start = subscr.metadata[:start] || subscr.start
    #STDERR.puts "              start==#{start.to_i.to_s}"
    start.to_i >= self.class.start_of_this_month
  end

  def self.start_of_this_month
    Time.now.utc.beginning_of_month.to_i
  end

  def self.end_of_this_month
    Time.now.utc.end_of_month.to_i
  end

  def plan
    SubscriptionPlanCached.find(plan_id) || subscribe_to_community
  end

  def eql?(customer)
    customer.id == id
  end

  def stripe_customer
    Stripe::Customer.retrieve(id)
  end

  def stripe_subscription(stripe_cus=stripe_customer)
    stripe_cus.subscriptions.first
  end

  alias :eql? :==

  def subscribe_to_community
    cust = stripe_customer
    if cust.respond_to? :deleted and cust.deleted == true
      Rails.logger.warn "**TODO** customer #{cust.id} exists but has been deleted -- cannot subscribe to community but treating as if we can"
      STDERR.puts "**TODO** customer #{cust.id} exists but has been deleted -- cannot subscribe to community but treating as if we can"
      Rails.cache.delete([:customer, :individual, cust.id])
      return SubscriptionPlanCached.community
    end
    community_plan = SubscriptionPlanCached.community
    subscr = stripe_subscription(cust)
    if subscr
      # has existing. update it.
      subscr.plan = community_plan.id
      subscr.save
    else
      # no subscription yet. create it.
      cust.subscriptions.create(:plan => community_plan.id)
    end
    Rails.cache.delete([:customer, :individual, cust.id])
    return community_plan
  end

  def self.generic_community
    return new(nil, :id => 'generic-community-customer', :plan_id => SubscriptionPlanCached.community.id)
  end
end
