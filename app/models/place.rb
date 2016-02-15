class Place
  attr_accessor :id, :formatted_address, :location, :address_components

  def initialize params
    @id = params[:_id].to_s # comes in as BSON object
    @formatted_address = params[:formatted_address]
    @location = Point.new params[:geometry][:geolocation]
    # NOTE assuming we need a point instantiated here same as array of acs
    @address_components = params[:address_components].map { |ac| AddressComponent.new ac }
  end

  def self.mongo_client
    Mongoid::Clients.default
  end

  def self.collection
    mongo_client["places"]
  end

  def self.load_all file
    json_string = File.read file
    json_data = JSON.parse json_string
    self.collection.insert_many json_data
  end
end
