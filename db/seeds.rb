require 'pp'
Photo.all.each { |photo| photo.destroy }
Place.all.each { |place| place.destroy }
Place.create_indexes
Place.load_all(File.open('./db/places.json'))
Dir.glob("./db/image*.jpg") {|f| photo=Photo.new; photo.contents=File.open(f,'rb'); photo.save}
Photo.all.each {|photo| place_id=photo.find_nearest_place_id 1*1609.34; photo.place=place_id; photo.save}
pp Place.all.reject {|pl| pl.photos.empty?}.map {|pl| pl.formatted_address}.sort
