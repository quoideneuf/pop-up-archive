class SubscriptionPlan < ActiveRecord::Base
  attr_accessible :name, :hours, :amount, :interval, :stripe_plan_id, :pop_up_hours

  def self.sync_with_stripe(spc)
    # spc is SubscriptionPlanCached (simple object)
    # we verify our local copy, if it exists, is identical to Stripe's.
    sp = find_by_stripe_plan_id(spc.id)
    if sp.nil?
      # we don't yet have a local copy. create one.
      sp = self.create(
      :stripe_plan_id => spc.id,
      :name => spc.name,
      :interval => spc.interval,
      :hours => spc.hours,
      :pop_up_hours => spc.hours.to_i,
      :amount => spc.amount
      )
    else

      # compare and update if necessary
      if spc.name != sp.name               then sp.name = spc.name end
      if spc.interval != sp.interval       then sp.interval = spc.interval end
      if spc.hours != sp.hours             then sp.hours = spc.hours end
      if spc.hours.to_i != sp.pop_up_hours then sp.pop_up_hours = spc.hours.to_i end
      if spc.amount != sp.amount           then sp.amount = spc.amount end
      sp.save

    end
    return sp
  end
end
