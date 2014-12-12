class CollectionGrant < ActiveRecord::Base
  acts_as_paranoid

  belongs_to :collection, :with_deleted => true
  belongs_to :collector, polymorphic: true

  attr_accessible :collection, :collection_id, :collector, :collector_id, :collector_type, :uploads_collection, :deleted_at
end
