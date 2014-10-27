module Billable
  extend ActiveSupport::Concern

  # mixin methods for User and Organization for billing/usage
  def billable_collections
    Collection.with_role(:owner, self)
  end

  def total_transcripts_report(ttype=:basic)
    total_secs = 0
    total_cost = 0
    cost_where = '=0'

    # for now, we have only two types. might make sense
    # longer term to store the ttype on the transcriber record.
    case ttype
    when :basic
      cost_where = '=0'
    when :premium
      cost_where = '>0'
    end

    # 'audio_files' relationship is equivalent to collections->items->audio_files
    # but we are only interested in billable audio_files, so loop like an organization
    # does: the long way, skipping any collections where this User != coll.billable_to
    billable_collections.each do |coll|
      next unless coll.billable_to == self
      coll.items.each do |item|
        item.audio_files.includes(:item).where('audio_files.duration is not null').each do|af|
          af.transcripts.unscoped.where("audio_file_id=#{af.id} and cost_per_min #{cost_where}").each do |tr|
            total_secs += tr.billable_seconds(af)
            total_cost += tr.cost(af)
          end
        end
      end
    end
    # cost_per_min is in 1000ths of a dollar, not 100ths (cents)
    # but we round to the nearest penny when we cache it in aggregate.
    # we make seconds and cost fixed-width so that sorting a string works
    # like sorting an integer.
    return { :seconds => "%010d" % total_secs, :cost => sprintf('%010.2f', total_cost.fdiv(1000)) }
  end

  # unlike total_transcripts_report, transcripts_billable_for_month_of returns hash of numbers not strings.
  def transcripts_billable_for_month_of(dtim=DateTime.now, transcriber_id)
    month_start = dtim.utc.beginning_of_month
    month_end = dtim.utc.end_of_month
    total_secs = 0
    total_cost = 0
    billable_collections.each do |coll|
      next unless coll.billable_to == self
      coll.items.each do |item|
        item.audio_files.includes(:item).where('audio_files.duration is not null').where(created_at: month_start..month_end).each do |af|
          af.transcripts.unscoped.where("audio_file_id=? and transcriber_id=?", af.id, transcriber_id).each do|tr|
            total_secs += tr.billable_seconds(af)
            total_cost += tr.cost(af)
          end
        end
      end
    end
    return { :seconds => total_secs, :cost => total_cost.fdiv(1000) }
  end

  def usage_for(use, now=DateTime.now)
    monthly_usages.where(use: use, year: now.utc.year, month: now.utc.month).sum(:value)
  end 

  def update_usage_for(use, rep, now=DateTime.now)
    monthly_usages.where(use: use, year: now.utc.year, month: now.utc.month).first_or_initialize.update_attributes!(value: rep[:seconds], cost: rep[:cost])
  end 

  def calculate_monthly_usages!
    months = (DateTime.parse(created_at.to_s)<<1 .. DateTime.now).select{ |d| d.strftime("%Y-%m-01") if d.day.to_i == 1 } 
    months.each do |dtim|
      ucalc = UsageCalculator.new(self, dtim)
      ucalc.calculate(Transcriber.basic, MonthlyUsage::BASIC_TRANSCRIPTS)
      ucalc.calculate(Transcriber.premium, MonthlyUsage::PREMIUM_TRANSCRIPTS)
    end 
  end 

  def owns_collection?(coll)
    has_role?(:owner, coll)
  end 

  def transcript_usage_report
    return {
      :basic_seconds => used_basic_transcripts[:seconds],
      :premium_seconds => used_premium_transcripts[:seconds],
      :basic_cost => used_basic_transcripts[:cost],
      :premium_cost => used_premium_transcripts[:cost],
    }   
  end 

  def used_basic_transcripts
    @_used_basic_transcripts ||= total_transcripts_report(:basic)
  end

  def used_premium_transcripts
    @_used_premium_transcripts ||= total_transcripts_report(:premium)
  end

  def get_total_seconds(ttype)
    ttype_s = ttype.to_s
    methname = 'used_' + ttype_s + '_transcripts'
    if transcript_usage_cache.has_key?(ttype_s+'_seconds')
      return transcript_usage_cache[ttype_s+'_seconds'].to_i
    else
      return send(methname)[:seconds].to_i
    end
  end

  def get_total_cost(ttype)
    ttype_s = ttype.to_s
    methname = 'used_' + ttype_s + '_transcripts'
    if transcript_usage_cache.has_key?(ttype_s+'_cost')
      return transcript_usage_cache[ttype_s+'_cost'].to_f
    else
      return send(methname)[:cost].to_f
    end
  end

end
