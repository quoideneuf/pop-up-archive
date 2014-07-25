class Speaker < ActiveRecord::Base

  attr_accessible :name

  has_many :timed_texts
  has_many :transcripts, through: :timed_texts

end
