desc "Move the item_id on image_files to imageable_id and add 'Item' as imageable_type"
  
task :update_images => :environment do
    @images = ImageFile.all
    @images.each do | img |
      if img.item_id.present?
        img.imageable_id = img.item_id
        img.imageable_type = "Item"
        img.save!
      end
    end
  
end