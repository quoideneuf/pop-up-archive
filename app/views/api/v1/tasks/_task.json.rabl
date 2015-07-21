attributes :id, :status, :name, :identifier
# do not reveal type in API response
# see https://github.com/popuparchive/pop-up-archive/issues/1171
#attribute :type_name => :type


node do |t|
  t.shared_attributes.inject({}) do |add, a|
    add[a] = t.send(a)
    add
  end
end
