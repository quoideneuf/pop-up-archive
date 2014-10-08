ActiveAdmin.register Organization do
  actions :all, :except => [:destroy]
  index do
    column :name, sortable: :name do |org| link_to org.name, superadmin_organization_path(org) end
    column :owner
    column 'Metered Use', :used_metered_hours_cache, sortable: :used_metered_hours_cache do |org|
      Api::BaseHelper::time_definition(org.used_metered_hours_cache||0)
    end
    column 'Unmetered Use', :used_unmetered_hours_cache, sortable: :used_unmetered_hours_cache do |org|
      Api::BaseHelper::time_definition(org.used_unmetered_hours_cache||0)
    end
  end

  filter :name

  show do
    panel "Organization Details" do
      attributes_table_for organization do
        row("ID") { organization.id }
        row("Name") { organization.name }
        row("Owner") { organization.owner_id ? (link_to organization.owner.name, superadmin_user_path(organization.owner)) : '(none)' }
        row("Plan Name") { organization.owner_id ? organization.owner.plan.name : '(none)' }
        row("Metered Storage") { Api::BaseHelper::time_definition(organization.used_metered_storage||0) }
        row("Unmetered Storage") { Api::BaseHelper::time_definition(organization.used_unmetered_storage||0) }
        row("Created") { organization.created_at }
        row("Updated") { organization.updated_at }
      end
    end
    panel "Users" do
      table_for organization.users do |tbl|
        tbl.column("Name") {|user| link_to user.name, superadmin_user_path(user) }
        tbl.column("Email") {|user| user.email }
        tbl.column("Last Sign In") {|user| user.last_sign_in_at }
        tbl.column("Metered Storage") {|user| Api::BaseHelper::time_definition(user.used_metered_storage||0) }
        tbl.column("Unmetered Storage") {|user| Api::BaseHelper::time_definition(user.used_unmetered_storage||0) }
        tbl.column("Plan Name") {|user| user.plan.name }
      end
    end
    panel "Collections" do
      table_for organization.collections do |tbl|
        tbl.column("Title") {|coll| link_to coll.title, superadmin_collection_path(coll) }
        tbl.column("Created") {|coll| coll.created_at }
        tbl.column("Storage") {|coll| coll.storage }
      end
    end
   
    active_admin_comments
  end

end
