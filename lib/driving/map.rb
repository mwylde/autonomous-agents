module Driving
  # Node class for points on the map. These have a world position
  # (given by lattitude/longitude) and a set of other nodes to which
  # this one is connected by a road of some kind.
  class Node
    attr_accessor :x, :y, :neighbors
    def initialize(x, y, neighbors = Set.new)
      @x = x
      @y = y
      @neighbors = neighbors
    end
  end

  # A graph of Nodes represented by an adjacency list. Each node
  # represents a point on a road, and each edge represents a segment
  # of a road. Nodes with more than two edges are intersections.
  class Map
    attr_accessor :map

    # Creates a new map from a json file containing the graph data. An
    # appropriate json file can be generated from an osm file by using
    # the osm_converter application in the bin/ directory.
    def initialize(json)
      graph = YAML.load(json)
      nodes = {}

      # initial values for min/max. note: these are the highest/lowest values of
      # lat/long possible, such that min is initially set to the highest
      # possible value, etc.
      lat_min = 90
      lat_max = -90
      long_min = 180
      long_max = -180

      # determine the extreme values
      graph.each do |k,v|
        lat_min = v[0] if v[0] < lat_min
        lat_max = v[0] if v[0] > lat_max
        long_min = v[1] if v[1] < long_min
        long_max = v[1] if v[1] > long_max
      end

      @lat_min = lat_min
      @lat_max = lat_max
      @long_min = long_min
      @long_max = long_max

      # store the the highest (x,y) coordinates of the map
      @world_max = latlong_to_world lat_max, long_max

      # create a new node with world coordinates
      graph.each do |k,v|
        world = latlong_to_world v[0], v[1]
        nodes[k] = Node.new(world[0], world[1])
      end
        
      # now that all of the nodes have been created, we do a second
      # pass to get all of the references
      graph.each do |k,v|
        v[2].each do |neighbor_k|
          nodes[k].neighbors << nodes[neighbor_k]
        end
      end

      @map = Set.new(nodes.values)
    end

    def latlong_to_world(lat, long)
      a = [lat, long]
      
      # shift
      a[0] = lat - @lat_min
      a[1] = long - @long_min

      # scale
      a[0] = 1000 * a[0]
      a[1] = 1000 * a[1]

      return a
    end

    def self.from_file(filename)
      File.open(filename) do |f|
        Map.new(f.read)
      end
    end
  end
end
