ActiveAdmin.register MonthlyUsage do
  actions :all, :except => [:edit, :destroy]
  index do
    column :entity
    column :entity_id
    column :entity_type
    column :month
    column :year
    column :use
    column :value
  end

  filter :month
  filter :year
  filter :entity_id
  filter :entity_type

end
