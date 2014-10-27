desc "Move the item_id on image_files to imageable_id and add 'Item' as imageable_type"
  
task :update_images => :environment do
  if column_exists?(:image_files, :imageable_id)
    ImageFile.each do | img |
      if img.item_id.exists?
        img.imageable_id = img.item_id
        img.imageable_type = "Item"
      end
    end
    else
      puts "Run rake db:migrate update the image_files table"
  end
  
end