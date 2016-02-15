class Point
  attr_accessor :longitude, :latitude

  def initialize coord_hash
    @latitude = coord_hash[:lat] || coord_hash[:coordinates][1]
    @longitude = coord_hash[:lng] || coord_hash[:coordinates][0]
  end

  def to_hash
    { "type":"Point", "coordinates":[@longitude, @latitude] } # GeoJSON format
  end
end
