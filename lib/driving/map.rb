module Driving
  # Node class for points on the map. These have a world position
  # (given by lattitude/longitude) and a set of other nodes to which
  # this one is connected by a road of some kind.
  class Node
    attr_accessor :lat, :long, :neighbors
    def initialize(lat, long, neighbors = Set.new)
      @lat = lat
      @long = long
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
      graph = JSON.parse(json)
      nodes = {}

      # initial values for min/max. note: these are the highest/lowest values of
      # lat/long possible, such that min is initially set to the highest
      # possible value, etc.
      lat_min = 90
      lat_max = -90
      long_min = 180
      long_max = -180
      
      # create a new node with the lat/long coordinates from the map
      graph.each do |k,v|
        nodes[k] = Node.new(v[0], v[1])

        # update min/max on extreme values.
        lat_min = v[0] if v[0] < lat_min
        lat_max = v[0] if v[0] > lat_max
        long_min = v[1] if v[1] < long_min
        long_max = v[1] if v[1] > long_max
      end

      # now that all of the nodes have been created, we do a second
      # pass to get all of the references
      graph.each do |k,v|
        v[2].each do |neighbor_k|
          nodes[k].neighbors << nodes[neighbor_k]
        end
      end

      @map = Set.new(nodes.values)
      @lat_min = lat_min
      @lat_max = lat_max
      @long_min = long_min
      @long_max = long_max

      @map.each do |n|
        world = latlong_to_world n.lat, n.long
        n.lat = world[0]
        n.long = world[1]
      end
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
