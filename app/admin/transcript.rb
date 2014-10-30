ActiveAdmin.register Transcript do
  actions :index, :show
  menu false
  index do
    column :audio_file
    #column :identifier
    #column :language 
    column :created_at 
    column :billable_to, :sortable => false
    column :transcriber
    column('Cost') do |t| number_to_currency(t.cost_dollars) end
  end

  filter :transcriber

  show do 
    panel "Transcript Details" do
      attributes_table_for transcript do
        row :id
        row :transcriber
        row :audio_file
        row :identifier
        row :created_at
        row :updated_at
        row :start_time
        row :end_time
        row :billable_to
        row :billable_seconds
        row("Cost") { number_to_currency(transcript.cost_dollars) }
      end     
    end
 
    active_admin_comments
  end

end
