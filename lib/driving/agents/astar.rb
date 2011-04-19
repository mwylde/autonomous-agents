require 'set'
java_import java.util.PriorityQueue

module Driving
  class AStarAgent < ClientAgent
    MAX_NODES_EXPANDED = 10000
    class AStarNode
      attr_accessor :state, :parent, :g, :h
      def initialize state, parent
        @state = state
        @parent = parent
        @g = 0
        @h = 0
      end

      def expand
        @state.neighbors.map{|n|
          AStarNode.new(n, self)
        }
      end

      def <=> y
          (@g + @h)  <=> (y.g + y.h)
      end

      def inspect
        "A*Node<state=#{state.pos}, g=#{g}, h=#{h}"
      end
        
    end
    # calculates the best route from the current node to the
    # destination node using A*
    def astar
      fringe = PriorityQueue.new
      fringe.add(AStarNode.new(@curr, nil))
      closed_states = Set.new
      nodes_expanded = 0
      until fringe.isEmpty
        current = fringe.peek
        fringe.remove current # stupid java
        next if closed_states.include? current
        return current if current.state == @goal

        expanded = current.expand
        
        closed_states << current.state
        # since we have a bunch of nodes that only go to a single
        # node, it seems kind of silly to count those as expansions
        nodes_expanded += 1 if expanded.size > 1
        
        return nil if nodes_expanded > MAX_NODES_EXPANDED
        expanded.each{|successor|
          successor.g = current.g + current.state.pos.dist(successor.state.pos)
          successor.h = successor.state.pos.dist @goal.pos
          fringe.add(successor)
        }
      end
      puts "Failed to find solution after #{nodes_expanded} expansions"
      return nil
    end

    def calculate_route
      node = astar()
      if node
        route = []
        while node.parent
          route << node.parent.state
          node = node.parent
        end
        route
      else
        []
      end
    end
    
    def handle_msg msg
      if msg[:map]
        x = msg.clone
        x.delete :map
        # puts "Got message + map: #{x.inspect}"
      else
        # puts "Got message: #{msg.inspect}"
      end

      @old_pos = @pos
      @old_phi = @phi
      @old_delta = @delta
      @old_speed = @speed
      @old_accel = @accel
      
      @phi = msg[:phi]
      @delta = msg[:delta]
      @speed = msg[:speed]
      @accel = msg[:accel]
      @pos = Point.new(*msg[:pos])
      # puts "Current pos: #{@pos}"
      @route ||= []

      if msg[:type] == :initial
        @map = Map.new(msg[:map])
        @old_pos = @pos
      end
      # find cloest node to our current pos
      @curr = @map.closest_node @pos

      case msg[:type]
      when :initial, :dest_change
        change_dest Point.new(*msg[:dest])
      end

      # puts "Got update"
      puts "Speed: #{@speed}"
      new_delta, new_accel = navigate
      send({:delta => new_delta, :accel => new_accel})
    end

    def change_dest p
      @dest = p
      @goal = @map.closest_node @dest
      @route = calculate_route
      puts "Route: #{@route.inspect}"
    end

    def socket; @socket; end
    
    def navigate
      if @route.size == 0
        puts "Can't navigate, no route #{@route.inspect}"
        return [0, 0]
      end
      # check if we're at the current way point
      at = @curr == @route[-1]
      # see if we've passed a way point since our last update, which
      # we determine by calculating the rectangle of the road that
      # we've passed since our last nav op and check if the current
      # waypoint is inside

      # to determine if we've passed a way point since our last update, we
      # create a pseudo-road object from the path traveled since the last nav
      # op, and then see if the current waypoint is within that
      # pseudo-road. (note: by pesudo-road, we mean to convey that a road is
      # meant to represent a connection between two nodes on the map, but we are
      # constructing a road object out of two arbitrary points on the map out of
      # convenience to use road's contain method.
      road = Road.new(@old_pos, @pos)
      @route.pop if at || road.contains(@route[0].pos)
      
      # find the difference in phi between our current position and
      # our next waypoint
      u = Vector.from_mag_dir 1, @phi
      v = @pos.subtract_point @route[-1].pos
      theta = Math.acos(u.dot(v)/v.mag)
      # on right side, should move left
      new_delta = 0
      if theta > v.dir
        new_delta = [@delta - 0.005, -Math::PI/2+0.01].max
      else
        new_delta = [@delta + 0.005, Math::PI/2-0.01].min
      end
      [new_delta, @speed > 5 ? 0 : 0.2]
    end
  end
end
