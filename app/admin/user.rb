ActiveAdmin.register User do
  actions :all, :except => [:edit, :destroy]
  index do
    column("Name") {|user| link_to user.name, superadmin_user_path(user) }
    column :email
    column :last_sign_in_at
    column :sign_in_count
    column 'Metered Use', :used_metered_storage_cache do |user|
      Api::BaseHelper::time_definition(user.used_metered_storage_cache)
    end
  end

  filter :email
  filter :name
  filter :organization

  show do
    panel "User Details" do
      attributes_table_for user do
        row("ID") { user.id }
        row("Name") { user.name }
        row("Email") { user.email }
        row("Organization") { user.organization_id ? (link_to user.organization.name, superadmin_organization_path(user.organization)) : '(none)' }
        row("Metered Storage") { Api::BaseHelper::time_definition(user.used_metered_storage) }
        row("Unmetered Storage") { Api::BaseHelper::time_definition(user.used_unmetered_storage) }
        row("Plan Name") { user.plan.name }
        #row("Plan Hours") { user.plan.hours.to_s + 'h (' + user.pop_up_hours_cache.to_s + 'h)' }
        #row("Plan Amount") { user.plan.amount }
        #row("Plan Interval") { user.plan.interval }
        row("Last Sign In") { user.last_sign_in_at }
        row("Sign In Count") { user.sign_in_count }
        row("Created") { user.created_at }
        row("Updated") { user.updated_at }
      end
    end

    active_admin_comments
  end

end
