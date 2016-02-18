class Photo
  attr_accessor :id, :location, :contents
  # attr_writer :contents

  def initialize params = {}
    @id = params[:_id].to_s if params[:_id]
    if params[:metadata] && params[:metadata][:location]
      @location = Point.new(params[:metadata][:location])
    end
  end

  def persisted?
    # has the instance been created in GridFS?
    !@id.nil?
  end

  def save
    # save to GridFS
    unless persisted?
      description = {}
      file = @contents
      gps = EXIFR::JPEG.new(file).gps
      # grab gps with exfir gem from file stored in @contents
      @location = Point.new lng: gps.longitude, lat: gps.latitude
      content_type = 'image/jpeg'
      description[:content_type] = content_type
      description[:metadata] = { location: @location.to_hash }
      grid_file = Mongo::Grid::File.new file.read, description
      grid_doc_id = Photo.mongo_client.database.fs.insert_one grid_file
      @id = grid_doc_id.to_s
    end
  end

  def self.mongo_client
    Mongoid::Clients.default
  end
end
