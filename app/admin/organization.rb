ActiveAdmin.register Organization do
  actions :all, :except => [:destroy]
  index do
    column :name, sortable: :name do |org| 
      link_to( org.name, superadmin_organization_path(org)) + raw('<br/>') + org.owner_contact
    end
    column :plan do |org| org.owner_id ? org.owner.plan.name : span('(none)', class: "empty") end
    column 'Usage', :premium_seconds, sortable: "transcript_usage_cache->'premium_seconds'" do |org|
      raw 'Premium: ' + \
      Api::BaseHelper::time_definition(org.get_total_seconds(:premium)||0) + \
      '&nbsp;' + number_to_currency(org.get_total_cost(:premium)||'0.00') + \
      '<br/>' + \
      'Basic: ' + \
      Api::BaseHelper::time_definition(org.get_total_seconds(:basic)||0) + \
      '&nbsp;' + number_to_currency(org.get_total_cost(:basic)||'0.00')
    end
  end

  filter :name

  show do
    panel "Organization Details" do
      attributes_table_for organization do
        row("ID") { organization.id }
        row("Name") { organization.name }
        row("Owner") { organization.owner_id ? (link_to organization.owner.name, superadmin_user_path(organization.owner)) : span(I18n.t('active_admin.empty'), class: "empty") }
        row("Plan Name") { organization.owner_id ? organization.owner.plan.name : span(I18n.t('active_admin.empty'), class: "empty") }
        row("Metered Storage") { Api::BaseHelper::time_definition(organization.used_metered_hours_cache||0) }
        row("Unmetered Storage") { Api::BaseHelper::time_definition(organization.used_unmetered_hours_cache||0) }
        row("Premium Transcripts") { Api::BaseHelper::time_definition(organization.get_total_seconds(:premium)||0) }
        row("Premium Cost") { number_to_currency(organization.get_total_cost(:premium)||'0.00') }
        row("Basic Transcripts") { Api::BaseHelper::time_definition(organization.get_total_seconds(:basic)||0) }
        row("Basic Cost") { number_to_currency(organization.get_total_cost(:basic)||'0.00') }
        row("Created") { organization.created_at }
        row("Updated") { organization.updated_at }
      end
    end
    panel "Monthly Usage" do
      table_for organization.monthly_usages do|tbl|
        tbl.column :yearmonth
        tbl.column :use
        tbl.column('Time') {|mu| Api::BaseHelper::time_definition(mu.value||0) }
      end
    end
    panel "Users" do
      table_for organization.users do |tbl|
        tbl.column("Name") {|user| link_to user.name, superadmin_user_path(user) }
        tbl.column("Email") {|user| user.email }
        tbl.column("Last Sign In") {|user| user.last_sign_in_at }
        tbl.column("Metered Storage") {|user| Api::BaseHelper::time_definition(user.used_metered_storage_cache||0) }
        tbl.column("Unmetered Storage") {|user| Api::BaseHelper::time_definition(user.used_unmetered_storage||0) }
        tbl.column("Plan Name") {|user| user.plan.name }
      end
    end
    panel "Collections" do
      table_for organization.collections do |tbl|
        tbl.column("Title") {|coll| link_to coll.title, superadmin_collection_path(coll) }
        tbl.column("Created") {|coll| coll.created_at }
        tbl.column("Storage Type") {|coll| coll.storage }
        tbl.column("Metered Storage") {|coll| Api::BaseHelper::time_definition(coll.used_metered_storage||0) }
        tbl.column("Unmetered Storage") {|coll| Api::BaseHelper::time_definition(coll.used_unmetered_storage||0) }
      end
    end

    active_admin_comments
  end

end
