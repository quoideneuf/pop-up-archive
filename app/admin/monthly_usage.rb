ActiveAdmin.register MonthlyUsage do
  actions :all, :except => [:edit, :destroy]
  index do
    column :entity
    column :entity_type
    column :month
    column :year
    column :use
    column 'Time', :value, sortable: :value do |mu|
      Api::BaseHelper::time_definition(mu.value)
    end
  end

  filter :month
  filter :year
  filter :entity_type

end
