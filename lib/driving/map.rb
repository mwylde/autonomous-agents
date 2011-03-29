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
      graph = YAML.load(json)
      nodes = {}
      
      # create a new node with the lat/long coordinates from the map
      graph.each do |k,v|
        nodes[k] = Node.new(v[0], v[1])
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

    def self.from_file(filename)
      File.open(filename) do |f|
        Map.new(f.read)
      end
    end
  end
end
