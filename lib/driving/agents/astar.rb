require 'set'
java_import java.util.PriorityQueue

module Driving
  class AStarAgent < ClientAgent
    MAX_NODES_EXPANDED = 3500
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
    end
    # calculates the best route from the current node to the
    # destination node using A*
    def astar
      fringe = PriorityQueue.new
      fringe.insert(AStarNode.new(@curr, nil))
      closed_states = Set.new
      nodes_expanded = 0
      unless fringe.isEmpty
        current = fringe.peek
        fringe.remove current # stupid java
        next if closed_states.include? current
        return current if current.state == @goal

        expanded = current.expand
        closed_states << current.state
        nodes_expanded += 1
        return nil if nodes_expanded > MAX_NODES_EXPANDED
        expanded.each{|successor|
          successor.g = current.g + current.state.pos.dist(successor.state.pos)
          successor.h = successor.state.pos.dist @goal.state.pos
          fringe.insert(successor)
        }
      end
    end

    def calulate_route
      node = astar
      route = []
      while node.parent
        route << node.parent.state
        node = node.parent
      end
      route
    end

    def closest_node point, map
      map.nodes.reduce([nil, 999999999999]){|best, n|
        dist = point.dist(n.pos)
        best[1] < dist ? best : [n, dist]
      }[0]
    end
    
    def handle_msg msg
      @old_pos
      @old_phi = @phi
      @old_delta = @delta
      @old_speed = @speed
      @old_accel = @accel
      
      @phi = msg[:phi]
      @delta = msg[:delta]
      @speed = msg[:speed]
      @accel = msg[:accel]
      @pos = Point.new(*msg[:pos])
      
      @route = []
      # find cloest node to our current pos
      @curr = closest_node @pos, @map
      case msg[:type]
      when :initial
        @map = Map.initialize(msg[:map])
        change_dest = Point.new(*msg[:dest])
      when :dest_change
        change_dest = Point.new(*msg[:dest])
      when :update
        new_delta, new_accel = navigate
        send({:delta => new_delta, :accel => new_accel})
      end
    end

    def change_dest p
      @dest = p
      @goal = closest_node @dest, @map
      @route = calculate_route
    end
    
    def navigate
      # check if we're at the current way point
      at = @curr == @route[-1]
      # see if we've passed a way point since our last update, which
      # we determine by calculating the rectangle of the road that
      # we've passed since our last nav op and check if the current
      # waypoint is inside
      road_segment = calculuate_road(@old_pos, @pos)
      passed = proc { @route[0].in_convex_poly road_segment }
      @route.pop if at || passed.call
      
      # find the difference in phi between our current position and
      # our next waypoint
      u = Vector.from_mag_dir 1, @phi
      v = @pos.subtract_point @route[-1].pos
      theta = Math.acos(u.dot(v)/v.mag)
      # on right side, should move left
      new_delta = 0
      if theta > v.dir
        new_delta = [@delta - 0.1, -Math.pi/2].max
      else
        new_delta = [@delta + 0.1, Math.pi/2].min
      end
      [new_delta, 0.2]
    end
  end
end
