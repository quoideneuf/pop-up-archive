ActiveAdmin.register Organization do
  actions :all, :except => [:destroy]
  index do
    column("Name") {|org| link_to org.name, superadmin_organization_path(org) }
    column :owner
  end

  filter :name

  show do
    panel "Organization Details" do
      attributes_table_for organization do
        row("ID") { organization.id }
        row("Name") { organization.name }
        row("Owner") { organization.owner_id ? (link_to organization.owner.name, superadmin_user_path(organization.owner)) : '(none)' }
        row("Plan Name") { organization.owner.plan.name }
        row("Created") { organization.created_at }
        row("Updated") { organization.updated_at }
      end
    end
    panel "Users" do
      table_for organization.users do |tbl|
        tbl.column("Name") {|user| link_to user.name, superadmin_user_path(user) }
        tbl.column("Email") {|user| user.email }
        tbl.column("Last Sign In") {|user| user.last_sign_in_at }
        tbl.column("Metered Storage") {|user| Api::BaseHelper::time_definition(user.used_metered_storage) }
        tbl.column("Unmetered Storage") {|user| Api::BaseHelper::time_definition(user.used_unmetered_storage) }
        tbl.column("Plan Name") {|user| user.plan.name }
      end
    end
   
    active_admin_comments
  end

end
