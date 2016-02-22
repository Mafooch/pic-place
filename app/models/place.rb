class Place
  include ActiveModel::Model
  attr_accessor :id, :formatted_address, :location, :address_components

  def initialize params
    @id = params[:_id].to_s # comes in as BSON object
    @formatted_address = params[:formatted_address]
    @location = Point.new params[:geometry][:geolocation]
    # NOTE assuming we need a point instantiated here same as array of acs

    if params[:address_components]
      # NOTE does it make sense to assign nil to this instance variable if the
      # param isn't there. you can still call place.address_components and get
      # nil because it's a attr_accessor, but it won't be shown by just typing
      # place in the console
      @address_components = params[:address_components].map { |ac| AddressComponent.new ac }
    end
  end

  def destroy
    Place.collection.find(_id: BSON::ObjectId.from_string(@id)).delete_one
    # TODO extract string id to bson away to a module in lib. a util module?
  end

  def near max_meters = nil
    near_query_hash = { :$near => self.location.to_hash }
    near_query_hash[:$maxDistance] = max_meters if max_meters
    docs_near = Place.collection.find "geometry.geolocation" => near_query_hash
    places_near = Place.to_places docs_near
  end

  def photos offset = 0, limit = 0
    place_bson_id = BSON::ObjectId.from_string @id
    photo_docs = Photo.find_photos_for_place(place_bson_id).skip(offset).limit(limit)
    photo_docs.map { |pd| Photo.new pd }
  end

  def persisted?
    !@id.nil?
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

  def self.find_by_short_name short_name
    collection.find "address_components.short_name": short_name
  end

  def self.to_places mongo_collection_view
    mongo_collection_view.map { |view| Place.new view }
  end

  def self.find id
    bson_id = BSON::ObjectId.from_string id
    document = collection.find(_id: bson_id).first
    Place.new document if document
  end

  def self.all offset = 0, limit = 0
    docs = collection.find.skip(offset).limit(limit)
    docs.map { |doc| Place.new doc }
  end

  def self.get_address_components sort = { _id: 1 }, offset = 0, limit = nil
    pipeline = [
      { :$unwind => "$address_components" },
      { :$project => { address_components: 1, formatted_address: 1, "geometry.geolocation": 1 } },
      { :$sort => sort },
      { :$skip => offset }
    ]
    pipeline << { :$limit => limit } unless limit.nil?
    Place.collection.find.aggregate pipeline
  end

  def self.get_country_names
    country_name_coll = collection.find.aggregate([
        { :$project => { "address_components.long_name": true,
                         "address_components.types": true } },
        { :$unwind => "$address_components" },
        { :$match => { "address_components.types": "country" } },
        { :$group => { _id: "$address_components.long_name" } }
      ])
    country_array = country_name_coll.map { |c| c[:_id] }
  end

  def self.find_ids_by_country_code country_code
    id_coll = collection.find.aggregate([
      { :$match => { "address_components.types": "country",
                     "address_components.short_name": country_code } },
      { :$project => { _id: 1 } }
    ])
    id_array = id_coll.map { |c| c[:_id].to_s }
  end

  def self.create_indexes
    collection.indexes.create_one "geometry.geolocation" => Mongo::Index::GEO2DSPHERE
  end

  def self.remove_indexes
    collection.indexes.drop_one "geometry.geolocation_2dsphere"
  end

  def self.near point, max_meters = nil
    near_query_hash = { :$geometry => point.to_hash }
    near_query_hash[:$maxDistance] = max_meters if max_meters
    Place.collection.find({ "geometry.geolocation" => { :$near => near_query_hash } })
  end
end
