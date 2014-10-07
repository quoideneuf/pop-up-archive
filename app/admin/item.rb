ActiveAdmin.register Item do
  actions :all, :except => [:edit, :destroy]
  index do
    column :title, sortable: :title do |item| link_to item.title, superadmin_item_path(item) end
    column :created_at
    column :duration
  end

  filter :title

  show do 
    panel "Item Details" do
      attributes_table_for item do
        row("ID") { item.id }
        row("Title") { item.title }
        row("Collection") { link_to item.collection.title, superadmin_collection_path(item.collection) }
        row("Duration") { item.duration }
        row("Created") { item.created_at }
        row("Updated") { item.updated_at }
      end     
    end
    panel "Audio Files" do
      table_for item.audio_files do |tbl|
        tbl.column("ID") {|af| af.id }
        tbl.column("URL") {|af| af.url }
      end     
    end
    panel "Image Files" do
      table_for item.image_files do |tbl|
        tbl.column("ID") {|imgf| imgf.id } 
        tbl.column("URL") {|imgf| imgf.url }
      end     
    end
 
    active_admin_comments
  end

end
