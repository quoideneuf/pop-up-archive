class UsageCalculator

  attr_accessor :user, :dtim

  def initialize(user, dtim)
    @user = user 
    @dtim = dtim
  end

  def calculate(klass, usage_type)
    # get all tasks for the user's entity
    month_start = @dtim.utc.beginning_of_month
    month_end = @dtim.utc.end_of_month
    tasks = klass.where(status: :complete).where("extras -> 'entity_id' = ?", @user.entity.id.to_s).where(created_at: month_start..month_end)
    duration = tasks.inject(0){|sum, t| sum + t.usage_duration }
    user.update_usage_for(usage_type, duration, @dtim)
    duration
  end


end
