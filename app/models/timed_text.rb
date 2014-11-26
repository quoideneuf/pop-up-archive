class TimedText < ActiveRecord::Base
  attr_accessible :start_time, :end_time, :text, :confidence, :speaker_id
  belongs_to :transcript
  belongs_to :speaker

  delegate :audio_file, to: :transcript

  def as_json(options = :sigil)
    if options == :sigil
      {audio_file_id: transcript.audio_file_id, confidence: confidence, text: text, start_time: start_time, end_time: end_time }
    else
      super
    end
  end

  def as_indexed_json
    as_json.tap do |json|
      json[:transcript] = json.delete :text
    end
  end

  def offset_as_ts
    Time.at(start_time).getgm.strftime('%H:%M:%S')
  end

end
