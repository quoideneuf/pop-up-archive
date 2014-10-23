class UsageCalculator

  attr_accessor :entity, :dtim

  def initialize(entity, dtim)
    @entity = entity
    @dtim = dtim
  end

  def calculate(klass, usage_type)
    # get all tasks for the user's entity
    month_start = @dtim.utc.beginning_of_month
    month_end = @dtim.utc.end_of_month
    if @entity.is_a?(User) and @entity.entity.is_a?(User)
      # user solo (no org)
      tasks = klass.where(status: :complete).where("extras -> 'user_id' = ?", @entity.id.to_s).where(created_at: month_start..month_end)
    elsif @entity.is_a?(User) and @entity.entity.is_a?(Organization)
      # user acting on behalf of Organization
      tasks = klass.where(status: :complete).where("extras -> 'entity_id' = ?", @entity.entity.id.to_s).where(created_at: month_start..month_end)
    elsif @entity.is_a?(Organization)
      # org (can this happen?)
      tasks = klass.where(status: :complete).where("extras -> 'entity_id' = ?", @entity.id.to_s).where(created_at: month_start..month_end)
    else
      raise "entity #{@entity.inspect} is neither an Organization nor a User"
    end
    duration = tasks.inject(0){|sum, t| sum + t.usage_duration }
    @entity.update_usage_for(usage_type, duration, @dtim)
    duration
  end


end
