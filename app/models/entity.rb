class Entity < ActiveRecord::Base
  attr_accessible :entity_type, :extra, :identifier, :is_confirmed, :item_id, :name, :score

  scope :confirmed, -> { where(is_confirmed: true) }
  scope :unconfirmed, -> { where(arel_table[:is_confirmed].eq(nil).or(arel_table[:is_confirmed].eq(false))) }
  scope :high_scoring, -> { unconfirmed.where(arel_table[:score].gteq(0.95)) }
  scope :middle_scoring, -> { unconfirmed.where(arel_table[:score].gt(0.75).and(arel_table[:score].lt(0.95))) }
  scope :low_scoring, -> { unconfirmed.where(arel_table[:score].lteq(0.75).or(arel_table[:score].eq(nil))) }
  
  serialize :extra, JSON

  belongs_to :item, touch: true

  def as_indexed_json
    {entity: name, category: category }
  end

  def inspect
    "#<Entity #{as_json.delete_if{|k, v| k =~ /_at$/ || v.nil? || k == 'id' }.to_json.gsub(/\{|\}/, '')}>"
  end
end
