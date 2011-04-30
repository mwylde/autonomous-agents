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

    def to_hash
      {
        :pos => @pos.to_a,
        :neighbors => neighbors.collect{|n| n.to_hash}
      }
    end

    def self.from_hash params
      pos = Point.from_a params[:pos]
      neighbors = params[:neighbors].collect{|n| Node.from_hash(n)}
      self.new pos, neighbors
    end
      
  end

  # Calculates the four points of the rectangle for the road segment
  # between p0 and p1
  def calculate_road p0, p1
    # unit vector pointing from p0 to p1
    n = (p1 - p0).normalize.normal_vector * ROAD_WIDTH
    
    a = p0 + n
    b = p0 - n
    c = p1 + n
    d = p1 - n
    [a, b, c, d]
  end

  class Road
    def self.naive_walls p0, p1
      n = (p1 - p0).normalize.normal_vector * ROAD_WIDTH

      [LineSegment.new(p0+n, p1+n), LineSegment.new(p0-n, p1-n)]
    end
    
    attr_accessor :p0, :p1, :n0, :n1, :naive, :walls
    def initialize(n0, n1, walls = nil)
      @n0, @n1 = n0, n1

      if walls.nil?
        @walls = Set.new(Road.naive_walls(@n0.pos, @n1.pos))
        @naive = true
      else
        @walls = walls
        @naive = false
      end
    end

    def to_s
      "Road: #{@p0} -> #{@p1} with #{@walls}"
    end

    def to_hash
      {
        :n0 => @n0.to_hash,
        :n1 => @n1.to_hash,
        :walls => @walls.collect{|w| w.to_a},
        :naive => @naive
      }
    end

    def self.from_hash params
      n0 = Node.from_hash params[:n0]
      n1 = Node.from_hash params[:n1]
      walls = params[:walls].collect{|w| LineSegment.from_a w}
      self.new n0, n1, walls
    end

    # FIXME This is a naive implementation which uses naive walls. 
    def contains p
      naive_walls = Road.naive_walls @n0.pos, @n1.pos
      a = naive_walls[0].p0
      b = naive_walls[0].p1
      c = naive_walls[1].p1
      d = naive_walls[1].p0
      p.in_convex_poly([a, b, c, d])
    end

    # finds the distance from p to each wall. returns a hash mapping the object
    # id of each wall to the distance from p to that wall.
    def dists_to_walls p
      result = {}
      @walls.each { |w| result[w.object_id] = w.dist_to_pt(p) }
      return result
    end

    # finds the unit vectors from p to the closest point to p on each
    # wall. returns a hash mapping the object id of each wall to the
    # corresponding vector.      
    def units_to_walls p
      result = {}
      @walls.each { |w| result[w.object_id] = w.unit_from_pt(p) }
      return result
    end
  end

  # A graph of Nodes represented by an adjacency list. Each node
  # represents a point on a road, and each edge represents a segment
  # of a road. Nodes with more than two edges are intersections.
  class Map
    attr_reader :nodes, :road_hash, :road_set, :lat_min, :lat_max,
    :long_min, :long_max, :world_max, :world_min

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
        @lat_min = v[0] if v[0] < @lat_min
        @lat_max = v[0] if v[0] > @lat_max
        @long_min = v[1] if v[1] < @long_min
        @long_max = v[1] if v[1] > @long_max
      end

      # store the the highest and lowest (x,y) coordinates of the map
      @world_max = latlong_to_world Point.new(lat_max, long_max)
      @world_min = latlong_to_world Point.new(lat_min+0.000001, long_min+0.000001)

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
      @road_hash = create_roads
      @road_set = road_set_from_hash @road_hash
    end

    def create_roads
      roads = {}
      
      @nodes.each do |n|
        n.neighbors.each do |m|
          road = Road.new(n, m)

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

      return roads
    end

    # returns a set of all the roads. this 
    def road_set_from_hash hash
      s = Set.new

      # the road hash is indexed by start point and then by end point
      hash.each do |p0, p0_hash|
        p0_hash.each do |p1, r|
          # FIXME: I think the fact that it's a set should handle the fact that
          # the double-hash has duplicate references to roads. If not, then I
          # can keep a list of sets of points that have been added and only add
          # a road if it's not in the list of set of points.
          s.add r
        end
      end

      return s
    end

    def get_road p0, p1
      if @road_hash[p0].nil? || @road_hash[p1].nil?
        raise "Neither point specified has any roads"
      elsif @road_hash[p0][p1].nil?
        raise "The points specified do not define a road"
      else
        @road_hash[p0][p1]
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
              # FIXME: LOTS MORE IMPLEMENTATINO
            end
          end
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

    def road_for_point point
      @road_set.find{|r|
        r.contains point
      }
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
