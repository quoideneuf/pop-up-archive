class Speaker < ActiveRecord::Base

  serialize :times

  attr_accessible :name, :times

  belongs_to :transcript
  has_many :timed_texts

end
