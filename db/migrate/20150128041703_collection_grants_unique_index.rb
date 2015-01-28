class CollectionGrantsUniqueIndex < ActiveRecord::Migration
  def up

    remove_index :collection_grants, name: 'index_collection_grants_on_user_id_and_collection_id'
    add_index :collection_grants, [:collection_id, :collector_id, :collector_type], name: 'index_collection_grant_collector_type_collection', unique: true
  end

  def down
  end
end
