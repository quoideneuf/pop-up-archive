ActiveAdmin.register MonthlyUsage do
  actions :index, :show
  index do
    column :entity
    #column :entity_type
    column :yearmonth
    column :use
    column 'Cost', :cost, sortable: :cost do |mu|
      link_to number_to_currency(mu.cost), superadmin_monthly_usage_path(mu)
    end
    column 'Time', :value, sortable: :value do |mu|
      Api::BaseHelper::time_definition(mu.value||0)
    end
  end

  filter :yearmonth
  filter :entity_type

  show do
    panel "Monthly Usage Details" do
      attributes_table_for monthly_usage do
        row :id
        row :entity
        row :entity_type
        row :yearmonth
        row :use
        row("Cost") { number_to_currency(monthly_usage.cost) }
        row("Time") { Api::BaseHelper::time_definition(monthly_usage.value||0) }
      end
    end

    panel "Transcripts" do
      table_for monthly_usage.transcripts do |tbl|
        tbl.column("ID") {|tr| link_to tr.identifier, superadmin_transcript_path(tr) }
        tbl.column("Cost") {|tr| number_to_currency(tr.cost_dollars) }
        tbl.column("Transcriber") {|tr| link_to tr.transcriber.name, superadmin_transcriber_path(tr.transcriber) }
        tbl.column("Created") {|tr| tr.created_at }
      end
    end
  end

end
