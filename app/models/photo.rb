class Photo
  attr_accessor :id, :location
  attr_writer :contents

  def initialize params = {}
    @id = params[:_id].to_s if params[:_id]
    if params[:metadata] && params[:metadata][:location]
      @location = Point.new(params[:metadata][:location])
    end
    @place = params[:metadata][:place] if params[:metadata] && params[:metadata][:place]
  end

  def place
    # binding.pry
    @place.nil? ? nil : Place.find(@place)
  end

  def place= place
    if place.is_a? BSON::ObjectId
      @place = place
      # binding.pry
    else
    end
  end

  def contents
    grid_file = Photo.fs_bucket.find_one(_id: BSON::ObjectId.from_string(@id))
    # NOTE find_one returns a GridFS document whereas find with results in a view
    # and find with .first results in a BSON doc
    if grid_file
      buffer = ""
      grid_file.chunks.reduce([]) do |x,chunk|
          buffer << chunk.data.data
      end
      return buffer
    end
  end

  def persisted?
    # has the instance been created in GridFS?
    !@id.nil?
  end

  def save
    # save to GridFS
    if persisted?
      photo_view = Photo.fs_bucket.find(_id: BSON::ObjectId.from_string(@id))
      update_hash = {}
      if @location
        update_hash = { "metadata.location.coordinates": [@location.latitude, @location.longitude] }
      end
      if @place

      end
      photo_view.update_one(:$set => update_hash)
    else
      description = {}
      file = @contents
      gps = EXIFR::JPEG.new(file).gps
      file.rewind
      # grab gps with exfir gem from file stored in @contents
      @location = Point.new lng: gps.longitude, lat: gps.latitude
      content_type = 'image/jpeg'
      description[:content_type] = content_type
      description[:metadata] = { location: @location.to_hash, place: @place }
      grid_file = Mongo::Grid::File.new file.read, description
      grid_doc_id = Photo.fs_bucket.insert_one grid_file
      @id = grid_doc_id.to_s
    end
  end

  def destroy
    grid_file = Photo.fs_bucket.find_one(_id: BSON::ObjectId.from_string(@id))
    Photo.fs_bucket.delete_one grid_file
  end

  def find_nearest_place_id max_meters
    binding.pry
    nearest_id = Place.near(@location, max_meters)
                      .limit(1).projection(_id: true).first[:_id]
  end

  def self.mongo_client
    Mongoid::Clients.default
  end

  def self.fs_bucket
    mongo_client.database.fs
  end

  def self.all skip = 0, limit = 0
    docs = fs_bucket.find.skip(skip).limit(limit)
    docs.map { |d| Photo.new d }
  end

  def self.find id
    doc = fs_bucket.find(_id: BSON::ObjectId.from_string(id)).first
    doc.nil? ? nil : Photo.new(doc)
  end
end
