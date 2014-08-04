class MonthlyUsage < ActiveRecord::Base

  belongs_to :entity, :polymorphic => true
  attr_accessible :entity, :entity_id, :entity_type, :month, :year, :use, :value

  PREMIUM_TRANSCRIPTS = 'premium transcripts'
  BASIC_TRANSCRIPTS   = 'basic transcripts'

end
