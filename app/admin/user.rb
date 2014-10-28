ActiveAdmin.register User do
  actions :all, :except => [:edit, :destroy]
  index do
    column :name, sortable: :name do |user|
      link_to( user.name, superadmin_user_path(user) ) + raw( '<br/>' + user.email )
    end
    column :last_sign_in_at
    column 'Plan', :subscription_plan_id, sortable: :subscription_plan_id do |user|
      user.plan.name + ' [' + (user.subscription_plan_id.to_s||'(nil)') + ']'
    end
    column 'Usage', :premium_seconds, sortable: "transcript_usage_cache->'premium_seconds'" do |user|
      raw 'Premium: ' + \
      Api::BaseHelper::time_definition(user.get_total_seconds(:premium)||0) + \
      '&nbsp;' + number_to_currency(user.get_total_cost(:premium)||'0.00') + \
      '<br/>' + \
      'Basic: ' + \
      Api::BaseHelper::time_definition(user.get_total_seconds(:basic)||0) + \
      '&nbsp;' + number_to_currency(user.get_total_cost(:basic)||'0.00')
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
        row("Organization") {
          user.organization_id \
          ? (link_to user.organization.name, superadmin_organization_path(user.organization)) \
          : span(('none'), class: "empty")
        }
        row("Metered Storage") { Api::BaseHelper::time_definition(user.used_metered_storage||0) }
        row("Unmetered Storage") { Api::BaseHelper::time_definition(user.used_unmetered_storage||0) }
        row("Plan") { user.plan.name + ' ' + user.plan.hours.to_s + 'h (billed per ' + user.plan.interval + ')' }
        row("Premium Transcripts") { Api::BaseHelper::time_definition(user.get_total_seconds(:premium)||0) }
        row("Premium Cost") { number_to_currency(user.get_total_cost(:premium)||'0.00') }
        row("Basic Transcripts") { Api::BaseHelper::time_definition(user.get_total_seconds(:basic)||0) }
        row("Basic Cost") { number_to_currency(user.get_total_cost(:basic)||'0.00') }
        row("Last Sign In") { user.last_sign_in_at }
        row("Sign In Count") { user.sign_in_count }
        row("Created") { user.created_at }
        row("Updated") { user.updated_at }
      end
    end

    panel "Monthly Usage" do
      table_for user.monthly_usages.order('yearmonth desc') do|tbl|
        tbl.column :yearmonth
        tbl.column :use
        tbl.column('Cost') {|mu| div :class => "cost" do number_to_currency(mu.cost); end }
        tbl.column('Time') {|mu| Api::BaseHelper::time_definition(mu.value||0) }
      end
    end

    panel "Collections" do
      table_for user.collections do|tbl|
        tbl.column("Title") {|coll| link_to coll.title, superadmin_collection_path(coll) }
        tbl.column("Created") {|coll| coll.created_at }
        tbl.column("Storage Type") {|coll| coll.storage }
        tbl.column("Metered Storage") {|coll| Api::BaseHelper::time_definition(coll.used_metered_storage||0) }
        tbl.column("Unmetered Storage") {|coll| Api::BaseHelper::time_definition(coll.used_unmetered_storage||0) }
      end
    end

    panel "Owned Organizations" do
      table_for user.owned_organizations do|tbl|
        tbl.column :id
        tbl.column("Name") {|org| link_to org.name, superadmin_organization_path(org) }
        tbl.column("Metered Storage") {|org| Api::BaseHelper::time_definition(org.used_metered_storage||0) }
        tbl.column("Unmetered Storage") {|org| Api::BaseHelper::time_definition(org.used_unmetered_storage||0) }
      end
    end

    active_admin_comments
  end

end
