require 'set'
if RUBY_ENGINE == 'jruby'
  java_import java.util.PriorityQueue
else
  require File.expand_path(File.dirname(__FILE__)) + '/../pqueue'
end

module Driving
  class AStarAgent < ClientAgent
    # The maximum number of nodes to expand during A* search. Larger
    # values will ensure that we can find paths to destinations that
    # are further away, while smaller values will make planning faster.
    MAX_NODES_EXPANDED = 10000
    # Mode in which the agent simply goes straight, following the
    # current road
    STRAIGHT_MODE = :straight
    # Mode in which the agent executes a turn towards the next
    # waypoint
    TURN_MODE = :turn
    # Mode in which the agent stops and replans
    REPLAN_MODE = :replan
    # Just goes forward until outside of the range of the start node
    START_MODE = :start
    
    def initialize *args
      super *args

      # current operation mode of the agent
      @mode = START_MODE
    end

    # Node class used for A* navigation. Includes the state, which is
    # the Driving::Node this AStarNode represents, parent, which is
    # the AStarNode that expanded this one, and g and h which are the
    # current cost and expected remaining cost respectively.
    class AStarNode
      attr_accessor :state, :parent, :g, :h
      def initialize state, parent
        @state = state
        @parent = parent
        @g = 0
        @h = 0
      end

      # Creates an array of AStarNodes from this node's neighbors
      def expand
        @state.neighbors.map{|n|
          AStarNode.new(n, self)
        }
      end

      def <=> y
          (@g + @h)  <=> (y.g + y.h)
      end

      def > y
        (self <=> y) > 0
      end

      def inspect
        "A*Node<state=#{state.pos}, g=#{g}, h=#{h}"
      end
        
    end
    
    # calculates the best route from the current node to the
    # destination node using A*
    def astar
      fringe = PriorityQueue.new
      # figure out which node of our road we're facing
      facing, other = [@curr.n0, @curr.n1].sort_by{|n|
        ((n.pos - @pos).dir - @phi).abs
      }
      fringe.add(AStarNode.new(facing, AStarNode.new(other, nil)))
      closed_states = Set.new
      nodes_expanded = 0
      until fringe.isEmpty
        current = fringe.remove
        next if closed_states.include? current.state
        return current if current.state == @goal

        expanded = current.expand
        
        closed_states << current.state
        # since we have a bunch of nodes that only go to a single
        # node, it seems kind of silly to count those as expansions
        nodes_expanded += 1 if expanded.size > 1
        
        if nodes_expanded > MAX_NODES_EXPANDED
          puts "Reached max expansion depth"
          return nil
        end
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

      resp = {}
      
      if msg[:type] == :initial
        @map = Map.new(msg[:map])
        @old_pos = @pos
        @mode = :start
        @start_node = @map.closest_node @pos
      end
      # find the road segment we're currently on, if we're on one
      @old_curr = @curr
      @curr = @map.road_for_point @pos
      # we're off-road, we can't do much but stop
      if !@curr
        puts "Fell off road"
        resp[:phi] = 0
        resp[:accel] = -20
        send resp
        return
      end
      
      case msg[:type]
      when :initial, :dest_change
        change_dest Point.new(*msg[:dest])
        @old_curr = @curr
      end

      # puts "Got update"
      # puts "Speed: #{@speed}"
      new_delta, new_accel = navigate
      resp[:phi] = new_delta
      resp[:accel] = new_accel
      
      renders = ["@g.set_color Color.blue"]
      facing, other = get_facing [@curr.n0, @curr.n1]
      @route.each{|r|
        s = "dot Point.new(#{r.pos.x.to_s}, #{r.pos.y.to_s})"
        if r == @turn_to_node
          s = "@g.set_color Color.red; #{s}; @g.set_color Color.blue"
        end
        renders << s
      }
      resp[:renders] = renders
      
      send resp

      if @mode == REPLAN_MODE
        puts "Off-track, recalculating..."
        change_dest @dest
        self.mode = START_MODE
      end
    end

    def change_dest p
      @dest = p
      @goal = @map.closest_node @dest
      @route = calculate_route
      puts "Route: #{@route.inspect}"
    end

    def socket; @socket; end

    # Neville's algorithm for finding the spline through n points
    # (en.wikipedia.org/wiki/Neville's_algorithm)
    def neville(ps, x)
      n = ps.size
      xs = ps.map{|p| p.x}
      ys = ps.map{|p| p.y}
      ps = []
      n.times{|i|
        (n-i).times{|j|
          if i == 0
            ps[j] = ys[j]
          else
            ps[j] = ((x-xs[j+i])*ps[j]+(xs[j]-x)*ps[j+1])/(xs[j]-xs[j+i])
          end
        }
      }
      ps[0]
    end

    def get_facing nodes
      nodes.sort_by{|n|
        if false && n.pos.dist(@pos) < 0.1
          10000000
        else
          ((n.pos - @pos).dir - @phi).abs
        end
      }
    end

    def straight_navigate
      facing, other = get_facing [@curr.n0, @curr.n1]
      [(facing.pos-other.pos).dir, @speed > 5 ? 0 : 0.5]
    end

    def turn_navigate
      # for now we're cheating and just setting our phi to be parallel
      # to the road
      phi = (@turn_to_node.pos-@pos).dir
      
      [phi, @speed > 2 ? -0.1 : 0]
    end

    def mode= mode
      puts "Mode transitioned from #{@mode} to #{mode}"
      @mode = mode
    end

    # Figure out which mode we're in and run the corresponding
    # navigation action
    def navigate
      if @route.size == 0
        return [@phi, 0]
      elsif @route.size == 1
        return [@phi, 0]
      end

      facing, other = get_facing [@curr.n0, @curr.n1]
      if @mode == STRAIGHT_MODE
        # check if we should transition
        if facing.pos.dist(@pos) < ROAD_WIDTH
          @route.pop
          self.mode = TURN_MODE
          @turn_from_node = facing
          @turn_to_node = @route[-1]
          if false && !facing.neighbors.include?(@route[-1])
            self.mode = REPLAN_MODE
            return [@phi, -5]
          end
          return turn_navigate
        else
          return straight_navigate
        end
      elsif @mode == TURN_MODE
        closest = @map.closest_node @pos
        if closest.pos.dist(@pos) > ROAD_WIDTH * 2
          self.mode = STRAIGHT_MODE
          return straight_navigate
        else
          return turn_navigate
        end
      elsif @mode == START_MODE
        if @start_node.pos.dist(@pos) > ROAD_WIDTH * 2
          self.mode = STRAIGHT_MODE
          @route.pop if @route[-1] == @start_node
        end
        return [@phi, 2]
      end
    end

    # The basic idea behind this algorithm is as follows. We want to
    # figure out how often we get to run, so we compute a rolling
    # average of the time between the last five invocation of
    # handle_message. We use this and our current speed to predict how
    # far ahead we'll be by the next time we get to react. We find the
    # point that we predict we'll reach, and then use spline
    # interpolation to figure out the angle we'll want to be at when
    # we get there.
    #
    # Actually, that's how I'd like to do it. For now, I'm just going
    # to calculute the tangent of the spline at the current point and
    # try to turn so that I'm parallel
    def get_new_delta_spline
      return @delta unless @last && @route.size > 1
      # points that define the center-road spline
      x, y, z = @last.pos, @route[-1].pos, @route[-2].pos

      # points that define the edge-road spline
      xp, _, yp, _ = Driving::calculate_road(x, y)
      _, _, zp, _  = Driving::calculate_road(y, z)

      # average of the above points, to get the path that we want the
      # car to follow (the center of the lane)
      xb = Point.new((x.x + xp.x)/2, (x.y + xp.y))
      yb = Point.new((y.x + yp.x)/2, (y.y + yp.y))
      zb = Point.new((z.x + zp.x)/2, (z.y + zp.y))

      # find the approx tangent
      xs = [@pos.x-0.05, @pos.x+0.05]
      a, b = xs.map{|x| Point.new(x, neville([xb, yb, zb], x)) }
      phi_wanted = (a-b).dir
    end

  end
end
