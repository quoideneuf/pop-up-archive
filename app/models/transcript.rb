class Transcript < ActiveRecord::Base
  attr_accessible :language, :audio_file_id, :identifier, :start_time, :end_time, :confidence, :transcriber_id, :cost_per_min, :cost_type

  belongs_to :audio_file
  belongs_to :transcriber
  has_one :item, through: :audio_file
  has_many :timed_texts, order: 'start_time ASC'
  has_many :speakers

  default_scope includes(:timed_texts)

  after_save :update_item

  def update_item
    IndexerWorker.perform_async(:update, item.class.to_s, item.id) if item
  end

  def timed_texts
    super.each do |tt|
      tt.transcript = self
    end
    super
  end

  def set_confidence
    sum = 0.0
    count = 0.0
    self.timed_texts.each{|tt| sum = sum + tt.confidence.to_f; count = count + 1.0}
    if count > 0.0
      average = sum / count
      self.update_attribute(:confidence, average)
    end
    average
  end

  def as_json(options={})
    { sections: timed_texts }
  end

  # def to_doc(format=:srt)
  #   action_view = ActionView::Base.new(Rails.configuration.paths["app/views"])
  #   action_view.class_eval do 
  #     include Rails.application.routes.url_helpers
  #     include Api::BaseHelper
  #     def protect_against_forgery?; false; end
  #   end

  #   action_view.render(template: 'api/v1/transcripts/show', formats: [format], locals: {transcript: self})
  # end

  def to_srt
    srt = ""
    timed_texts.each_with_index do |tt, index|

      end_time = tt.end_time
      end_mils = '000'

      if (index + 1) < timed_texts.size
        end_time_max = [(timed_texts[index + 1].start_time - 1), 0].max
        end_time = [tt.end_time, end_time_max].min
        end_mils = '999'
      end

      if (index > 0)
        srt += "\r\n" 
      end

      srt += "#{index + 1}\n"
      srt += "#{format_time(tt.start_time)},000 --> #{format_time(end_time)},#{end_mils}\n"
      srt += tt.text + "\n"
    end
    srt
  end

  def is_premium?
    self.transcriber_id == Transcriber.premium.id
  end 

  # returns a User or Organization
  def billable_to
    audio_file.billable_to
  end

  # returns the billable seconds
  # optional single arg is the audio_file this transcript references,
  # to avoid the sql load overhead when calculating (see User.transcripts_billable_for_month_of)
  def billable_seconds(af=audio_file)
    if end_time == 120 and start_time == 0 and cost_per_min == 0

      # 2min preview is free 
      # TODO better way to identify these. Perhaps a special Transcriber?
      return 0

    elsif af.duration

      # prefer audio file over actual transcript time
      # since we want people to pay for the privilege
      # of discovering parts of their audio are unintelligible.
      return af.duration

    else

      # default is the transcript length
      return end_time - start_time

    end
  end 

  # returns a float representing 1000ths of a dollar
  def cost(af=audio_file)
    secs = billable_seconds(af)
    mins = secs.fdiv(60)
    return cost_per_min.to_f * mins.to_f
  end

  # returns a float in dollars
  def cost_dollars(af=audio_file)
    return cost(af) / 1000
  end
    
  private

  def format_time(seconds)
    Time.at(seconds).getgm.strftime('%H:%M:%S')
  end

end
