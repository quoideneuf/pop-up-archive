ActiveAdmin.register AudioFile do
  actions :index, :show
  menu false
  index do
    column :filename, sortable: :file do |af| link_to truncate(af.filename||af.id, :length => 20), superadmin_audio_file_path(af) end
    column :created_at
    column :duration
    column('Collection') do |af| link_to truncate(af.collection.title, :length => 20), superadmin_collection_path(af.collection) end
    column('Item') do |af| link_to truncate(af.item.title, :length => 20), superadmin_item_path(af.item) end
    column('Status') do |af| af.current_status end
  end

  filter :file

  member_action :nudge, method: :post do
    Rails.logger.warn("recover: #{params}")
    af = AudioFile.find params[:id]
    af.recover_async
    flash[:notice] = "On the road to recovery!"
    redirect_to :action => :show
  end

  action_item :only => :show, if: proc{ audio_file.stuck? } do
    link_to "Recover", superadmin_audio_file_path(audio_file)+'/nudge', method: :post
  end 

  show do 
    panel "Audio File Details" do
      attributes_table_for audio_file do
        row("ID") { audio_file.id }
        row("Filename") { audio_file.filename }
        row("URL") { audio_file.url }
        row("Collection") { link_to audio_file.collection.title, superadmin_collection_path(audio_file.collection) }
        row("Item") { link_to audio_file.item.title, superadmin_item_path(audio_file.item) }
        row("Storage") { audio_file.storage_configuration }
        row("User") { link_to audio_file.user.name,  superadmin_user_path(audio_file.user) }
        row("Duration") { audio_file.duration }
        row("Format") { audio_file.format }
        row("Metered") { audio_file.metered }
        row("Transcoded") { audio_file.transcoded_at }
        row("Created") { audio_file.created_at }
        row("Updated") { audio_file.updated_at }
        row("Status") { audio_file.current_status }
      end     
    end
    panel "Tasks" do
      table_for audio_file.tasks.order('created_at desc') do |tbl|
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

    panel "Transcripts" do
      table_for audio_file.transcripts do |tbl|
        tbl.column("ID") {|tr| link_to tr.identifier, superadmin_transcript_path(tr) }
        tbl.column("Wholesale Cost") {|tr| number_to_currency(tr.cost_dollars) }
        tbl.column("Retail Cost") {|tr| number_to_currency(tr.retail_cost_dollars) }
        tbl.column("Transcriber") {|tr| link_to tr.transcriber.name, superadmin_transcriber_path(tr.transcriber) }
        tbl.column("Is Billable") {|tr| tr.is_billable }
        tbl.column("Is Premium") {|tr| tr.is_premium? }
        tbl.column("Billable") {|tr| link_to tr.billable_to.name, (tr.billable_to.is_a?(User) ? superadmin_user_path(tr.billable_to) : superadmin_organization_path(tr.billable_to)) }
      end
    end
 
    active_admin_comments
  end

end
