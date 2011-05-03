require 'set'
if RUBY_ENGINE == 'jruby'
  java_import java.util.PriorityQueue
else
  require File.expand_path(File.dirname(__FILE__)) + '/../pqueue'
end

module Driving
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

    def inspect
      "A*Node<state=#{state.pos}, g=#{g}, h=#{h}"
    end
  end
  module AStarMixin
    # The maximum number of nodes to expand during A* search. Larger
    # values will ensure that we can find paths to destinations that
    # are further away, while smaller values will make planning faster.
    MAX_NODES_EXPANDED = 10000

    # calculates the best route from the current node to the
    # destination node using A*
    def astar pos, phi, current_road, goal
      fringe = PriorityQueue.new
      # figure out which node of our road we're facing
      facing, other = [current_road.n0, current_road.n1].sort_by{|n|
        ((n.pos - pos).dir - phi).abs
      }
      fringe.add(AStarNode.new(facing, AStarNode.new(other, nil)))
      closed_states = Set.new [other]
      nodes_expanded = 0
      until fringe.isEmpty
        current = fringe.remove
        next if closed_states.include? current.state
        return current if current.state == goal

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
          successor.h = successor.state.pos.dist goal.pos
          fringe.add(successor)
        }
      end
      puts "Failed to find solution after #{nodes_expanded} expansions"
      return nil
    end

    def calculate_route pos, phi, current_road, goal
      node = astar pos, phi, current_road, goal
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
  end
  
  class AStarAgent < ClientAgent
    include AStarMixin
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
      end
    end

    def change_dest p
      @dest = p
      @goal = @map.closest_node @dest
      @route = calculate_route @pos, @phi, @curr, @goal
      self.mode = START_MODE
      puts "Route: #{@route.inspect}"
    end

    def socket; @socket; end

    def get_facing nodes
      nodes.sort_by{|n|
        ((n.pos - @pos).dir - @phi).abs
      }
    end

    def straight_navigate
      facing, other = get_facing [@curr.n0, @curr.n1]
      [(facing.pos-other.pos).dir, @speed > 15 ? 0 : 0.5]
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
          return turn_navigate
        else
          return straight_navigate
        end
      elsif @mode == TURN_MODE
        closest = @map.closest_node @pos
        
        # sometimes the current node fails to get removed from the
        # route, which leads to issues when we next get to TURN_MODE
        # and the old node hasn't yet been popped
        @route.delete closest
        
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
  end
end
