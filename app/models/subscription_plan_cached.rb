require 'subscription_plan'

class SubscriptionPlanCached

# this class does *NOT* front a db table directly.
# it is more of a write-through caching manager,
# for keeping the Stripe subscription plans
# in sync with the local db. The Stripe plan is authoritative.
# We just sync it locally since (a) plans rarely change
# and (b) we want to be able to save remote API calls
# but still use/display user plan data.

  def self.all
    Rails.cache.fetch([:plans, :group, :all], expires_in: 30.minutes) do
      Stripe::Plan.all(count: 100).map {|p| new(p) }.tap do |plans|
        plans.each do |plan|
          Rails.cache.write([:plans, :individual, plan.id], plan, expires_in: 30.minutes)
        end
      end
    end
  end

  def self.ungrandfathered
    Rails.cache.fetch([:plans, :group, :ungrandfathered], expires_in: 30.minutes) do
      all.select { |p| (p.name ||'')[0] != '*' && p != organization }
    end
  end

  def self.find(id)
    Rails.cache.fetch([:plans, :individual, id], expires_in: 30.minutes) do
      all.find { |p| p.id == id }
    end
  end

  def self.community
    Rails.cache.fetch([:plans, :group, :community], expires_in: 30.minutes) do
      # TODO name is different in stripe test-vs-prod; reconcile them (standardize on prod names)
      ungrandfathered.find { |p| p.id.match(/community$/) and p.name == 'Community'} || create(id: '2_community', name: 'Community', amount: 0)
    end
  end

  def self.organization
    Rails.cache.fetch([:plans, :group, :organization], expires_in: 30.minutes) do
      all.find { |p| p.name == 'Organization' } || create(hours: 100, name: 'Organization', amount: 0)
    end
  end

  def self.create(options)
    plan_id = "#{options[:hours]||2}-#{SecureRandom.hex(8)}"
    interval = options[:interval] || 'month'
    new(Stripe::Plan.create(id: plan_id,
      name: options[:name],
      amount: options[:amount],
      currency: 'USD',
      interval: interval)).tap do |plan|
      Rails.cache.delete([:plans, :group, :all])
      Rails.cache.delete([:plans, :group, :ungrandfathered])
      Rails.cache.delete([:plans, :group, :community])
      Rails.cache.write([:plans, :individual, plan_id], plan, expires_in: 30.minutes)
    end
  end

  def self.reset_cache
    Rails.cache.delete([:plans, :group, :all])
    Rails.cache.delete([:plans, :group, :ungrandfathered])
    Rails.cache.delete([:plans, :group, :community])
  end

  def initialize(plan)
    @id = plan.id
    @hours = calculate_plan_hours(plan.id)
    @name = plan.name
    @amount = plan.amount
    @interval = plan.interval
    SubscriptionPlan.sync_with_stripe(self)
  end

  # if the plan id has _business_ or _enterprise_ in it, we'll do premium transcripts
  def has_premium_transcripts?
    self.id.match(/_(business|enterprise)_/)
  end

  attr_reader :name, :amount, :hours, :id, :interval

  def eql?(plan)
    plan.id == id
  end

  alias_method :==, :eql?

  private

  def calculate_plan_hours(id)
    hours = id.split(/\-|_/)[0].to_i
    if hours == 0
      1
    else
      hours
    end
  end
end
