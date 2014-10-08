ActiveAdmin.register User do
  actions :all, :except => [:edit, :destroy]
  index do
    column :name, sortable: :name do |user| 
      link_to user.name, superadmin_user_path(user) 
    end
    column :email
    column :last_sign_in_at
    column 'Metered Use', :used_metered_storage_cache, sortable: :used_metered_storage_cache do |user|
      Api::BaseHelper::time_definition(user.used_metered_storage_cache||0)
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
        row("Organization") { user.organization_id ? (link_to user.organization.name, superadmin_organization_path(user.organization)) : span(I18n.t('active_admin.empty'), class: "empty") }
        row("Metered Storage") { Api::BaseHelper::time_definition(user.used_metered_storage||0) }
        row("Unmetered Storage") { Api::BaseHelper::time_definition(user.used_unmetered_storage||0) }
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

    panel "Monthly Usage" do
      table_for user.monthly_usages do|tbl|
        tbl.column :month
        tbl.column :year
        tbl.column :use
        tbl.column('Time') {|mu| Api::BaseHelper::time_definition(mu.value||0) }
      end
    end

    panel "Collections" do
      table_for user.collections do|tbl|
        tbl.column("Title") {|coll| link_to coll.title, superadmin_collection_path(coll) }
        tbl.column("Created") {|coll| coll.created_at }
        tbl.column("Storage") {|coll| coll.storage }
      end
    end

    active_admin_comments
  end

end
