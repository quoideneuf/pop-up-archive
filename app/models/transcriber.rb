class Transcriber < ActiveRecord::Base

  # IMPORTANT: cost_per_min is in 1000ths of a dollar, not 100ths (cents)
  # so e.g. $0.062 is recorded as 62
  attr_accessible :name, :cost_per_min, :url, :description

  has_many :transcripts

  def self.basic
    self.find_by_name('google_voice')
  end

  def self.premium
    self.find_by_name('speechmatics')
  end

end
