# wonky explicit syntax because RABL doesn't seem to treat
# Elasticsearch::Model::Response::Result objects like ActiveRecord objects
# so 'attributes' does not work as expected.
return { :name => @object.name, :id => @object.id }
