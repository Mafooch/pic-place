class Photo
  attr_accessor :id, :location, :contents
  # attr_writer :contents

  def initialize params = {}
    @id = params[:_id].to_s if params[:_id]
    if params[:metadata] && params[:metadata][:location]
      @location = Point.new(params[:metadata][:location])
    end
  end

  def self.mongo_client
    Mongoid::Clients.default
  end
end
