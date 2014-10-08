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
      needs_update = false
      if spc.name != sp.name
        puts "sp name has changed from #{sp.name} to #{spc.name}"
        sp.name = spc.name 
        needs_update = true 
      end
      if spc.interval != sp.interval
        puts "sp interval has changed from #{sp.interval} to #{spc.interval}"
        sp.interval = spc.interval
        needs_update = true 
      end
      if spc.hours.to_i != sp.hours.to_i
        puts "sp hours has changed from #{sp.hours} to #{spc.hours}"
        sp.hours = spc.hours
        needs_update = true
      end
      if spc.hours.to_i != sp.pop_up_hours
        puts "sp pop_up_hours has changed from #{sp.pop_up_hours} to #{spc.hours.to_i}"
        sp.pop_up_hours = spc.hours.to_i
        needs_update = true 
      end
      if spc.amount.to_i != sp.amount.to_i
        puts "sp amount has changed from #{sp.amount} to #{spc.amount}"
        sp.amount = spc.amount
        needs_update = true 
      end
      sp.save if needs_update

    end
    return sp
  end

  # return a SubscriptionPlanCached object
  def as_cached
    return SubscriptionPlanCached.find(self.stripe_plan_id)
  end

end
