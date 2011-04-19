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

  # Calculates the four points of the rectangle for the road segment
  # between p0 and p1
  def self.calculate_road p0, p1
    # unit vector pointing from p0 to p1
    n = (p1 - p0).normalize.normal_vector * ROAD_WIDTH
    
    a = p0 + n
    b = p0 - n
    c = p1 + n
    d = p1 - n
    [a, b, c, d]
  end

  class Road < LineSegment
    def self.naive_walls p0, p1
      n = (p1 - p0).normalize.normal_vector * ROAD_WIDTH

      Set.new [Wall.new(p0+n, p1+n), Wall.new(p0-n, p1-n)]
    end
    
    attr_accessor :p0, :p1, :naive, :walls
    def initialize(p0, p1, walls = [])
      @p0 = p0
      @p1 = p1

      if walls.nil?
        @walls = self.naive_walls p0, p1
        @naive = true
      else
        @walls = walls
        @naive = false
      end
    end
  end

  class Wall < LineSegment
    attr_accessor :p0, :p1
    def initialize(p0, p1)
      @p0 = p0
      @p1 = p1
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

      # create a two-layered hash storing roads
      @roads = create_roads
    end

    def create_roads
      roads = {}
      
      @nodes.each do |n|
        n.neighbors.each do |m|
          road = Road.new(n.pos, m.pos)

          # the hash is indexed by both start pos and end pos, but we don't care
          # about directionality, so we store the road wall object both ways in
          # the two-layered hash.
          # we also only store a wall object if a wall object for those points
          # doesn't already exist. this is because we want there to only be one
          # real road object, so that updating it propoagets. 
          
          if roads[n.pos].nil?
            roads[n.pos] = { m.pos => road }
          elsif roads[n.pos][m.pos].nil?
            roads[n.pos][m.pos] = road
          end

          if roads[m.pos].nil?
            roads[m.pos] = { n.pos => road }
          elsif roads[m.pos][n.pos].nil?
            roads[m.pos][n.pos] = road
          end
        end
      end
    end

    def clip_walls
      @nodes.each do |n|
        if n.neighbors.size == 2
          ms = n.neighbors
          u0 = (ms[0].pos - n.pos).normalize!
          u1 = (ms[1].pos - n.pos).normalize!

          # unit vector pointing towards the inner wall intersection.
          u = (u0 + u1).normalize!
          inner_pt = n.pos + u*ROAD_WIDTH

          @roads[n][ms[0]].walls.each do |w|
            if w.hits inner_pt
          
        end
      end
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

    def closest_node point
      @nodes.reduce([nil, 999999999999]){|best, n|
        dist = point.dist(n.pos)
        best[1] < dist ? best : [n, dist]
      }[0]
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
