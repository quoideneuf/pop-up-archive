class Transcriber < ActiveRecord::Base

  attr_accessible :name, :cost_per_min

  has_many :transcripts

  def basic
    self.find_by_name('google_voice')
  end

end
