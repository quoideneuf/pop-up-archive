class Role < ActiveRecord::Base
  has_and_belongs_to_many :users, :join_table => :users_roles
  has_and_belongs_to_many :organizations, :join_table => :organizations_roles
  belongs_to :resource, :polymorphic => true
  
  scopify

  def single_designee
    if organizations.size > 1 or users.size > 1 
      raise "More than one Organization and/or User designated for Role #{id} #{name}"
    elsif organizations.size == 1
      organizations.first
    elsif users.size == 1
      users.first
    else
      raise "No Organization or User designated to Role #{id} #{name}"
    end
  end

end
