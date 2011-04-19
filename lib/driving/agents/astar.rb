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

      if msg[:type] == :initial
        @map = Map.new(msg[:map])
        @old_pos = @pos
      end
      # find the road segment we're currently on, if we're on one
      @old_curr = @curr
      @curr = @map.road_for_point @pos
      # we're off-road, we can't do much
      if !@curr
        puts "Fell off road"
        return
      end

      resp = {}
      
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
      @route.each{|r|
        s = "dot Point.new(#{r.pos.x.to_s}, #{r.pos.y.to_s})"
        if r == @curr.n0 || r == @curr.n1
          s = "@g.set_color Color.yellow; #{s}; @g.set_color Color.blue"
        end
        renders << s
      }
      resp[:renders] = renders
      
      send resp

      if @needs_replan
        puts "Off-track, recalculating..."
        change_dest @dest
        @need_replan = false
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
        if n.pos.dist(@pos) < 0.1
          10000000
        else
          ((n.pos - @pos).dir - @phi).abs
        end
      }
    end
    
    def navigate
      if @route.size == 0
        return [0, 0]
      elsif @route.size == 1
        return [0, 0]
      end

      facing, other = get_facing [@curr.n0, @curr.n1]
      # for now we're cheating and jsut setting our phi to be parallel
      # to the road
      phi = (facing.pos-other.pos).dir

      # check if we've moved onto a different road since our last time
      # running
      if @old_curr != @curr
        # make sure we're on the right track. If we're not,
        # replan
        waypoint, passed = [@curr.n0, @curr.n1].sort_by{|n|
          n.pos.dist(@route[-1].pos)
        }
        if waypoint != @route[-1] && waypoint != @route[-2]
          @needs_replan = true
          # slow down as fast as possible
          return [0, -5]
        else
          # otherwise pop the passed node off the queue and continue
          @route.pop
          phi = (@route[-1].pos-@pos).dir
        end
      end

      # If we're clsoe to the end point we want to slow down so we can
      # make the turn
      accel = 1
      if facing.pos.dist(@pos) < 10
        #accel = -0.5
      elsif @speed > 5
        accel = 0
      end

      [phi, accel]
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
