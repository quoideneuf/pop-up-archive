attributes :id, :title, :description, :items_visible_by_default, :token

node :number_of_items do |coll|
  coll.items.count
end

node(:urls) do |coll|
  { self: url_for(api_collection_path(coll)) }
end

node (:storage) do |coll|
  coll.default_storage.provider
end

child :image_files do |af|
  extends 'api/v1/image_files/image_file'
end
