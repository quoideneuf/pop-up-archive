ActiveAdmin.register AudioFile do
  actions :all, :except => [:edit, :destroy]
  menu false
  index do
    column :filename, sortable: :file do |af| link_to af.filename, superadmin_audio_file_path(af) end
    column :created_at
    column :transcoded_at
    column :format
    column :duration
    column :metered
    column('Collection') do |af| link_to af.collection.title, superadmin_collection_path(af.collection) end
    column('Item') do |af| link_to af.item.title, superadmin_item_path(af.item) end
  end

  filter :file

  show do 
    panel "Audio File Details" do
      attributes_table_for audio_file do
        row("ID") { audio_file.id }
        row("Filename") { audio_file.filename }
        row("URL") { audio_file.url }
        row("Collection") { link_to audio_file.collection.title, superadmin_collection_path(audio_file.collection) }
        row("Item") { link_to audio_file.item.title, superadmin_item_path(audio_file.item) }
        row("Duration") { audio_file.duration }
        row("Format") { audio_file.format }
        row("Metered") { audio_file.metered }
        row("Transcoded") { audio_file.transcoded_at }
        row("Created") { audio_file.created_at }
        row("Updated") { audio_file.updated_at }
      end     
    end
    panel "Tasks" do
      table_for audio_file.tasks do |tbl|
        tbl.column("Type") {|task| link_to task.type, superadmin_task_path(task) }
        tbl.column("Identifier") {|task| task.identifier }
        tbl.column("Created") {|task| task.created_at }
        tbl.column("Status") {|task| task.status }
#        tbl.column("Extras") do |task| 
#          attributes_table_for task.extras do 
#            task.extras.keys.each do |e| 
#              row(e) { s = task.extras[e]; s.length < 50 ? s : s.slice(0,50)+'...' } 
#            end
#          end 
#        end 
      end     
    end
 
    active_admin_comments
  end

end
