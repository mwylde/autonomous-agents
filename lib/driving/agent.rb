module Driving
  class ServerAgent

    MAX_CRUMBS = 1000
    
    DEFAULT_WIDTH = 1.5

    DEFAULT_LENGTH = 3.5

    DEFAULT_PHI = Math::PI*2.75/4

    DEFAULT_SPEED = 0.0

    STATE_UPDATE_FREQUENCY = 100.0
    MOVE_FREQUENCY = 10.0

    attr_reader :id, :pos, :phi, :delta, :delta_speed, :speed, :accel, :w, :l,
    :tw, :tl, :u, :n, :ne, :nw, :se, :sw, :crumbs, :north, :map
    
    # Creates a default agent with positional parameters set to 0; requires
    # width and heigh tspecification
    def initialize(id, map, pos = Point.new(*DEFAULT_AGENT_POS_A),
                   w = DEFAULT_WIDTH, l = DEFAULT_LENGTH, phi = DEFAULT_PHI,
                   delta = 0, delta_speed = 0, speed = DEFAULT_SPEED, accel = 0)
      @id = id
      @w = w      # car width
      @l = l      # car length
      @tw = w/10  # tire width
      @tl = l/4   # tire length
      
      @map = map
      
      @pos = pos
      update_phi phi
      # delta > 0 means turning to the right
      @delta = delta
      @delta_speed = delta_speed
      @speed = speed
      @accel = accel
      @crumbs = []
    end

    def to_hash
      {
        :pos => [@pos.x, @pos.y],
        :phi => @phi,
        :delta => @delta,
        :delta_speed => @delta_speed,
        :speed => @speed,
        :accel => @accel
      }
    end

    # Starts the update loop which periodically updates the state
    # variables. Spawns a thread, so non-blocking.
    # @param start_time Time the start time of the simulation 
    def run

      # update loop
      Thread.new do
        curr_time = Time.now
        
        loop do
          last_time = curr_time
          curr_time = Time.now

          @speed += @accel * (curr_time - last_time)
          @delta += @delta_speed * (curr_time - last_time)

          sleep 1.0 / STATE_UPDATE_FREQUENCY
        end
      end
               
      # move loop
      Thread.new do
        curr_time = Time.now
        
        loop do
          last_time = curr_time
          curr_time = Time.now
          
          move(curr_time - last_time)
          
          sleep 1.0 / MOVE_FREQUENCY
        end
      end
    end

    # set phi and phi dependencies
    def update_phi new_phi
      @phi = new_phi

      # instance variables that depend on phi
      @u = create_u
      @n = create_n
      @ne = create_ne
      @nw = create_nw
      @se = create_se
      @sw = create_sw
      @north = create_north
    end

    # set pos and pos dependencies
    def update_pos new_pos
      @pos = new_pos.clone

      # instance variables that depend on position
      @ne = create_ne
      @nw = create_nw
      @se = create_se
      @sw = create_sw
      @north = create_north
    end

    # set pos, phi, and dependencies thereof
    def update_pos_phi new_pos, new_phi
      @pos = new_pos
      @phi = new_phi

      # instance variables that depend on either position or phi
      @u = create_u
      @n = create_n
      @ne = create_ne
      @nw = create_nw
      @se = create_se
      @sw = create_sw
      @north = create_north
    end
      
    # unit vector pointing in the direction of phi
    def create_u
      Vector.new(Math.cos(@phi), Math.sin(@phi))
    end

    # unit vector pointing normal to u
    def create_n
      create_u.normal_vector
    end
      
    # position of northeast corner of agent (where north is in the dir of phi)
    def create_ne
      @pos + @n*(@w/2.0) + @u*(@l/2.0)
    end

    # position of northwest corner of agent (where north is in the dir of phi)
    def create_nw
      @pos - @n*(@w/2.0) + @u*(@l/2.0)
    end

    # position of southeast corner of agent (where north is in the dir of phi)
    def create_se
      @pos + @n*(@w/2.0) - @u*(@l/2.0)
    end

    # poisiton of southwest corner of agent (where north is in the dir of phi)
    def create_sw
      @pos - @n*(@w/2.0) - @u*(@l/2.0)
    end

    def create_north
      @pos + @u*(@l/2.0)
    end

    def nw_tire_pts
      # get the center of the tire
      c = @nw - @u*(@tl/2.0) - @n*(@tw/2.0)

      # get the scaled heading and normal vectors for the tire
      tire_u = @u.rotate(-@delta).scale(@tl/2.0)
      tire_n = @n.rotate(-@delta).scale(@tw/2.0)
      
      [ c + tire_u - tire_n, c + tire_u + tire_n,
        c - tire_u + tire_n, c - tire_u - tire_n ]
    end

    def ne_tire_pts
      # get the center of the tire
      c = @ne - @u*(@tl/2.0) + @n*(@tw/2.0)

      # get the scaled heading and normal vectors for the tire
      tire_u = @u.rotate(-@delta).scale(@tl/2.0)
      tire_n = @n.rotate(-@delta).scale(@tw/2.0)

      [ c + tire_u - tire_n, c + tire_u + tire_n,
        c - tire_u + tire_n, c - tire_u - tire_n ]
    end
    
    def se_tire_pts
      # get the scaled heading and normal vectors for the tire (since it's a
      # back tire, these are aligned with the car as a whole).
      u_scale = @u.scale @tl
      n_scale = @n.scale @tw

      [ @se + u_scale + n_scale, @se + u_scale, @se, @se + n_scale ]
    end

    def sw_tire_pts
      # get the scaled heading and normal vectors for the tire (since it's a
      # back tire, these are aligned with the car as a whole).
      u_scale = @u.scale @tl
      n_scale = @n.scale @tw

      [ @sw + u_scale, @sw + u_scale - n_scale, @sw - n_scale, @sw ]
    end

    

    def move t
      raise "Delta must be in [-Pi/2, Pi/2]" unless (@delta.abs <= Math::PI/2)
      
      if @delta.abs < 0.01
        move_straight t
      else
        move_curved t
      end

      if @crumbs.size >= MAX_CRUMBS
        @crumbs.pop
      end
      
      @crumbs.unshift @pos.clone
    end
    
    # Move the agent in a straight path as if time t (in seconds) has
    # elapsed. Note: this should only be used when delta is very small.
    def move_straight t
       update_pos @pos + @u*t*@speed
    end

    # Move the agent in a curved path as if time t (in seconds) has
    # elapsed. Note: this should be used instead of move_straight whenever delta
    # is sizeable.
    def move_curved t
      # this is the distance between the appropriate back tire and the point
      # around which the car rotates
      r = @l / Math.tan(@delta.abs)

      # this is the angle, in radians, of the arc of the concentric circles
      # which the car fills out in time t
      theta = @speed * t / r

      # FIXME: this shouldn't be necessary, but the car zooms off now even if
      # given no speed. this might be useful to save computation, though.
      if theta > 0.000001
        if @delta > 0
          rotate_pt = @se + @n*r
          update_pos_phi @pos.rotate_about(rotate_pt, -theta), @phi+theta
        else
          rotate_pt = @sw - @n*r
          update_pos_phi @pos.rotate_about(rotate_pt, theta), @phi-theta
        end
      end
    end

    # Causes the agent to accelerate or decellerate at a rate
    # determined by x for a time period t.
    # @param x Float the acceleration, in meters per second per second.
    # @param t Float the time, in seconds, to accelerate for.
    def accelerate x, t
      curr_time = Time.now
      
      Thread.new do
        until Time.now > start_time + t do
          last_time = curr_time
          curr_time = Time.now
          @speed += x * (curr_time - last_time)
          sleep 1.0 / STATE_UPDATE_FREQUENCY
        end
      end
    end

    # Causes the agent to accelerate or decellerate for a time period t at a
    # rate such that it reaches speed x.
    # @param x Float the target speed, in meters per second, to reach at the
    # end.
    # @param t Float the time, in seconds, to accelerate for.
    def accelerate_to x, t
      rate = (x - @speed) / t
      accelerate rate, t
    end

    # Causes the agents' wheels (angle delta) at a rate determined by x, for a
    # period of time t.
    # @param x Float the speed, in radians per second, to turn the wheel.
    # @param t Float the time, in seconds, to turn the wheel
    def wheel_turn x, t
      predicted_end_delta = @delta + x*t
      unless predicted_end_delta.abs < Math::PI/2
        raise "End wheel position must be in range [-pi/2, pi/2]"
      end

      curr_time = Time.now
      
      Thread.new do
        until Time.now > start_time + t do
          last_time = curr_time
          curr_time = Time.now
          @delta += x * (curr_time - last_time)
          sleep 1.0 / STATE_UPDATE_FREQUENCY
        end
      end
    end

    # Causes the agents' wheels (angle delta) to turn to a position x in a
    # period of time t.
    # @param x Float the angle to turn the wheels to.
    # @param t Float the time it should take to turn the wheels.
    def wheel_turn_to x, t
      unless x.abs < Math::PI/2
        raise "Target wheel position must be in range [-pi/2, pi/2]"
      end
        
      rate = (x - @delta) / t
      wheel_turn rate, t
    end
      

    def turn_left
      Thread.new do
        accelerate_to 0.5, 5
        sleep 3
        accelerate_to 0.1, 1
        sleep 1
        wheel_turn_to -Math::PI/4, 0.5
        sleep 0.5
        wheel_turn_to 0, 0.5
        sleep 0.5
        accelerate_to 0.5, 1
        sleep 1
        accelerate_to 0, 5
      end
    end

    def go_crazy
      @speed = 0.5
      Thread.new do
        loop do
          @delta = (rand - 0.5) * Math::PI/2
          sleep 5
        end
      end
    end

    def go_straight
      @speed = 0.5
      @delta = 0.0
    end
  end
end
