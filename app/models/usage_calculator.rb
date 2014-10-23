class UsageCalculator

  attr_accessor :entity, :dtim

  def initialize(entity, dtim)
    @entity = entity
    @dtim = dtim
  end

  def calculate(transcriber, usage_type)

    # finds all the transcripts for the time period and returns the total seconds and cost
    report = @entity.transcripts_billable_for_month_of(@dtim, transcriber.id)
    @entity.update_usage_for(usage_type, report, @dtim)
    report[:seconds]

  end


end
