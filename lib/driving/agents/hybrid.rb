ROOT = File.expand_path(File.dirname(__FILE__))
require "#{ROOT}/dynamical"
require "#{ROOT}/astar"

module Driving
  class HybridAgent < DynamicalAgent
    include AStarMixin
    
    # Mode in which the agent stops and replans
    REPLAN_MODE = :replan

    def handle_msg msg
      case msg[:type]
      when :initial, :dest_change
        @mode = START_MODE
        # get constant information
        @map = Map.new(msg[:map]) if msg[:map]
        @dest = Point.new(*msg[:dest])
        @radius = DYNAMICAL_AGENT_RADIUS
        @length = msg[:l] if msg[:l]
        @width = msg[:w] if msg[:w]
        @pos = Point.new(*msg[:pos])
        @curr = @map.road_for_point @pos
        # need to set this so it's ready to use next time
        @curr_time = Time.now
        @phi = msg[:phi]
        @start_node = @map.closest_node @pos
        # calculate A* route
        change_dest @dest
        
        # send initial response
        send({
               :phi => msg[:phi] + Math::PI / 8.0,
               :accel => 1.0,
               :delta => 0.0
             })
      else
        if msg[:type] == :unpause
          @curr_time = Time.now
        end
        # get state information
        @pos = Point.new(*msg[:pos])
        @phi = msg[:phi]
        @delta = msg[:delta]
        @delta_speed = msg[:delta_speed]
        @speed = msg[:speed]
        @accel = msg[:accel]

        # compute more advanced, dynamcial-specific things
        
        # FIXME: we need to replace this with keeping track of the last position's
        # curr_road and seeing if the new position has passed into a new road.
        @curr = @map.road_for_point @pos
        
        # prepare and send the response

        if @curr && @route.size > 0
          # do a mode transition if appropriate
          mode_transitions
          # compute the new phi value
          new_phi = navigate
          resp = { :phi => new_phi }

          resp[:accel] = 0 if @speed > 5.0

          # Render the obstacles
          renders = ["@g.set_color Color.red"]
          @obs.each do |o|
            c, r = o
            renders << "circle Point.new(#{c.x}, #{c.y}), #{r}"
          end
          # Render the target
          c = @target[0]
          r = @target[1]
          renders << "@g.set_color Color.blue"
          renders << "circle Point.new(#{c.x}, #{c.y}), #{r}"
          resp[:renders] = renders
          # Render the agent's bounding circle
          renders << "@g.set_color Color.lightGray"
          renders << "circle Point.new(#{@pos.x}, #{@pos.y}), #{@radius}"

          renders << "@g.set_color Color.white"
          @route.each{|r|
            s = "dot Point.new(#{r.pos.x.to_s}, #{r.pos.y.to_s})"
            if r == @target_node
              s = "@g.set_color Color.red; #{s}; @g.set_color Color.white"
            end
            renders << s
          }
          resp[:renders] = renders

        else
          resp = {:phi => @phi, :renders => []}
        end
        
        send resp
      end
    end

    
    def handle_message msg
      super msg
      if msg[:type] == :initial || msg[:type] == :dest_change
      end
    end

    def change_dest p
      @dest = p
      @goal = @map.closest_node @dest
      @route = calculate_route @pos, @phi, @curr, @goal
      self.mode = START_MODE
      puts "Route: #{@route.inspect}"
    end

    # this function defines the transition conditions between the
    # states of the FSA that controls the behavior of the agent
    def mode_transitions
      case @mode
      when START_MODE
        facing, _ = facing_node
        if facing
          @route.pop if @route[-1] == @start_node
          @target_node = @route.pop
          @target = create_tar @target_node.pos
          self.mode = NORMAL_MODE 
        end
      when NORMAL_MODE
        facing, other = facing_node
        if facing.pos.dist(@pos) < ROAD_WIDTH
          @target_node = @route.pop
          @target = create_tar @target_node.pos
          if facing.neighbors.size > 2
            self.mode = INTERSECTION_MODE
          else
            self.mode = TURN_MODE
          end
        end
      when INTERSECTION_MODE, TURN_MODE
        closest = @map.closest_node @pos
        if closest.pos.dist(@pos) > ROAD_WIDTH
          self.mode = NORMAL_MODE
        end
      end
    end

    # chooses a new phi according the the dynamical state of the world
    # and the current mode
    def navigate
      case @mode
      when START_MODE, NORMAL_MODE, TURN_MODE
        @obs = create_obs
      when INTERSECTION_MODE
        @obs = []
      end
      @last_time = @curr_time
      @curr_time = Time.now
      begin
        @phi + phi_dot * (@curr_time - @last_time)
      rescue
        puts $!
        @phi
      end
    end
  end
end
