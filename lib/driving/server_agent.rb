module Driving
  # Server agents represent agents in the environment. They have all
  # of the state variables needed to simulate agent movement on the
  # map. When running, they constantly update their state variables in
  # response to their current velocity and turning speed.
  class ServerAgent

    attr_reader :id, :pos, :phi, :delta, :delta_speed, :speed, :accel, :w, :l,
    :tw, :tl, :u, :n, :ne, :nw, :se, :sw, :crumbs, :north, :map, :dest, :renders,
    :curr_road
    attr_accessor :paused
    
    # Creates a default agent with positional parameters set to 0; requires
    # width and height specification
    def initialize(id, map, pos = Point.new(0,0),
                   w = AGENT_WIDTH, l = AGENT_LENGTH, phi = 0,
                   delta = 0, delta_speed = 0, speed = 0, accel = 0)
      @id = id
      @w = w                     # car width
      @l = l                     # car length 
      @tw = w*AGENT_TIRE_WIDTH   # tire width
      @tl = l*AGENT_TIRE_LENGTH  # tire length
      
      @map = map

      # this will set all the parameters which depend on pos and phi
      self.pos= pos
      self.phi= phi
      # delta > 0 means turning to the right
      @delta = delta
      @delta_speed = delta_speed
      @speed = speed
      @accel = accel
      @crumbs = []
    end

    # Converts an agent to a hash representation which can be sent
    # across a socket to a ClientAgent.
    def to_hash
      {
        :pos => @pos.to_a,
        :phi => @phi,
        :delta => @delta,
        :delta_speed => @delta_speed,
        :speed => @speed,
        :accel => @accel,
        :curr_road => @curr_road ? @curr_road.to_hash : nil
      }
    end

    # FIXME this is a very inefficient implementation that just searches through
    # all the roads when it's called. should ideally be tracking the current
    # road and updating whenever the agent moves into a new road.
    def find_curr_road
      @map.road_set.each do |road|
        return road if road.contains @pos
      end
      nil
    end

    # Starts the update loop which periodically updates the state
    # variables. Spawns a thread, so non-blocking.
    def run
      Thread.new do
        curr_time = Time.now

        loop do
          last_time = curr_time
          curr_time = Time.now
          if !@paused
            old_spd = @speed
            @speed += @accel * (curr_time - last_time)
            avg_spd = (old_spd + @speed) / 2.0
            
            @delta += @delta_speed * (curr_time - last_time)
            
            move curr_time-last_time, avg_spd
          end

          t = 1.0/AGENT_UPDATE_FREQ - (Time.now - curr_time)
          sleep t > 0.0 ? t : 0
        end
      end
    end

    # set phi and cache various attributes.
    def phi= new_phi
      @phi = new_phi

      cache_attributes
    end

    # set pos and cache various attributes.
    def pos= new_pos
      @pos = new_pos.clone

      cache_attributes
    end

    # this should be called whenever pos or phi is updated
    def cache_attributes
      # variables which depend on phi
      unless @phi.nil?
        @u = create_u
        @n = create_n
      end

      # variables which depend on pos and phi
      unless @phi.nil? || @pos.nil?
        @ne = create_ne
        @nw = create_nw
        @se = create_se
        @sw = create_sw
        @north = create_north
      end

      # variables which depend on pos
      unless @pos.nil?
        @curr_road = find_curr_road
      end
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

    # Moves the agent for the specified time and average speed over that
    # time. The speed needs to be specified (instead of the agent's speed
    # instance variable) so that average speed over the time interval can be
    # used, instead of instantaneous speed at the end.
    def move t, spd
      puts "Delta must be in [-Pi/2, Pi/2]" unless (@delta.abs <= Math::PI/2)

      @delta = [-Math::PI/2, @delta].max
      @delta = [Math::PI/2, @delta].min
      
      if @delta.abs < 0.01
        move_straight t, spd
      else
        move_curved t, spd
      end

      @crumbs.unshift @pos.clone
      @crumbs.pop if @crumbs.size >= AGENT_MAX_CRUMBS
    end
    
    # Move the agent in a straight path as if time t (in seconds) has elapsed,
    # with average speed spd during that time interval. Note: this should only
    # be used when delta is very small.
    def move_straight t, spd
       self.pos= @pos + @u*t*spd
    end

    # Move the agent in a curved path as if time t (in seconds) has elapsed,
    # with average speed spd during that time interval. Note: this should be
    # used instead of move_straight whenever delta is sizeable.
    def move_curved t, spd
      # this is the distance between the appropriate back tire and the point
      # around which the car rotates
      r = @l / Math.tan(@delta.abs)

      # this is the angle, in radians, of the arc of the concentric circles
      # which the car fills out in time t
      theta = spd * t / r

      if theta > 0.00000001
        if @delta > 0
          rotate_pt = @se + @n*r
          self.pos= @pos.rotate_about(rotate_pt, theta)
          self.phi= @phi + theta
        else
          rotate_pt = @sw - @n*r
          self.pos= @pos.rotate_about(rotate_pt, -theta)
          self.phi= @phi - theta
        end
      end
    end
  end
end
