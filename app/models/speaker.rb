class Speaker < ActiveRecord::Base

  serialize :times

  attr_accessible :name, :times, :transcript

  belongs_to :transcript
  has_many :timed_texts

end
