class Place
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
