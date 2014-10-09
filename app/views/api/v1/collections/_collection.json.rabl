attributes :id, :title, :description, :items_visible_by_default

node(:urls) do |i|
  { self: url_for(api_collection_path(i)) }
end

node (:storage) do |i|
  i.default_storage.provider
end

child :image_files do |af|
  extends 'api/v1/image_files/image_file'
end