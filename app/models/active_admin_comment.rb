class ActiveAdminComment < ActiveRecord::Base
  belongs_to :resource, polymorphic: true
  belongs_to :author, polymorphic: true

  attr_accessible :body, :namespace, :author_id, :author_type
end
