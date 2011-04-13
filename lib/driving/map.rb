module Driving
  # Node class for points on the map. These have a world position
  # (given by lattitude/longitude) and a set of other nodes to which
  # this one is connected by a road of some kind.
  class Node
    attr_accessor :pos, :neighbors
    def initialize(pos, neighbors = Set.new)
      @pos = pos
      @neighbors = neighbors
    end

    def inspect
      "(#{@pos.x}, #{@pos.y}) #{@neighbors.size} neighbors"
    end
  end

  # A graph of Nodes represented by an adjacency list. Each node
  # represents a point on a road, and each edge represents a segment
  # of a road. Nodes with more than two edges are intersections.
  class Map
    attr_reader :nodes, :lat_min, :lat_max, :long_min, :long_max, :world_max

    # Creates a new map from a json file containing the graph data. An
    # appropriate json file can be generated from an osm file by using
    # the osm_converter application in the bin/ directory.
    def initialize(hash)
      @graph = hash
      nodes = {}

      # initial values for min/max. note: these are the highest/lowest values of
      # lat/long possible, such that min is initially set to the highest
      # possible value, etc.
      @lat_min = 90
      @lat_max = -90
      @long_min = 180
      @long_max = -180

      # determine the extreme values
      @graph.each do |k,v|
        @lat_min = v[0] if v[0] < lat_min
        @lat_max = v[0] if v[0] > lat_max
        @long_min = v[1] if v[1] < long_min
        @long_max = v[1] if v[1] > long_max
      end

      # store the the highest (x,y) coordinates of the map
      @world_max = latlong_to_world Point.new(lat_max, long_max)

      # create a new node with world coordinates
      @graph.each do |k,v|
        world = latlong_to_world Point.new(v[0], v[1])
        nodes[k] = Node.new(world)
      end
        
      # now that all of the nodes have been created, we do a second
      # pass to get all of the references
      @graph.each do |k,v|
        v[2].each do |neighbor_k|
          nodes[k].neighbors << nodes[neighbor_k]
        end
      end

      @nodes = Set.new(nodes.values)
      @nodes.freeze
    end

    def latlong_to_world p

      latlong_displacement = p - Vector.new(@lat_min, @long_min) - Point::ZERO

      earth_radius = 3958.75 * 1609.0      # 1609 is miles -> meter conversion

      deg_to_rad = Math::PI / 180.0

      lat1 = @lat_min
      lat2 = p.x
      lng1 = @long_min
      lng2 = p.y

      d_lat = (lat2-lat1) * deg_to_rad
      d_lng = (lng2-lng1) * deg_to_rad
      a = Math.sin(d_lat/2.0) * Math.sin(d_lat/2.0) +
        Math.cos(lat1 * deg_to_rad) * Math.cos(lat2 * deg_to_rad) *
        Math.sin(d_lng/2.0) * Math.sin(d_lng/2.0)
      c = 2.0 * Math.atan2(Math.sqrt(a), Math.sqrt(1.0 - a))
      dist = earth_radius * c

      Point.from_vector Vector.from_mag_dir dist, latlong_displacement.dir
    end

    def self.from_file(filename)
      File.open(filename) do |f|
        Map.new(YAML.load(f.read))
      end
    end

    def to_hash
      @graph
    end
  end
end
