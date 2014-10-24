ActiveAdmin.register MonthlyUsage do
  actions :all, :except => [:edit, :destroy]
  index do
    column :entity
    column :entity_type
    column :yearmonth
    column :use
    column 'Cost', :cost, sortable: :cost do |mu|
      number_to_currency(mu.cost)
    end
    column 'Time', :value, sortable: :value do |mu|
      Api::BaseHelper::time_definition(mu.value||0)
    end
  end

  filter :yearmonth
  filter :entity_type

end
