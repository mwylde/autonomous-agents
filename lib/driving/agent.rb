module Driving
  class ServerAgent
    DEFAULT_WIDTH = 0.075

    DEFAULT_LENGTH = 0.1

    # these are the world coordinates  of (37.5716897, -122.0797629) in latlong.
    DEFAULT_POS = Point.new(27.3725, 52.4647)
    DEFAULT_PHI = Math::PI / 2 # Math::PI * 2.5 / 4.0

    DEFAULT_SPEED = 0.0

    
    attr_reader :id, :pos, :phi, :delta, :delta_speed, :speed, :accel, :w, :l,
    :tw, :tl, :u, :n, :ne, :nw, :se, :sw
    
    # Creates a default agent with positional parameters set to 0; requires
    # width and heigh tspecification
    def initialize(id, pos = DEFAULT_POS,
                   w = DEFAULT_WIDTH, l = DEFAULT_LENGTH, phi = DEFAULT_PHI,
                   delta = 0, delta_speed = 0, speed = DEFAULT_SPEED, accel = 0)
      @id = id
      @w = w     # car width
      @l = l     # car length
      @tw = w/10  # tire width
      @tl = l/4  # tire length
      

      @pos = pos
      update_phi phi
      # delta > 0 means turning to the right
      @delta = delta
      @delta_speed = delta_speed
      @speed = speed
      @accel = accel
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
      Thread.new do
        curr_time = Time.now
        loop do
          last_time = curr_time
          curr_time = Time.now
          move(curr_time - last_time)
          sleep 0.1
        end
      end
    end

    def update_phi new_phi
      @phi = new_phi

      # instance variables that depend on phi
      @u = create_u
      @n = create_n
      @ne = create_ne
      @nw = create_nw
      @se = create_se
      @sw = create_sw
    end

    def update_pos new_pos
      @pos = new_pos.clone

      # instance variables that depend on position
      @ne = create_ne
      @nw = create_nw
      @se = create_se
      @sw = create_sw
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
      @pos.add_vector(@n.scale @w/2.0).add_vector(@u.scale @l/2.0)
    end

    # position of northwest corner of agent (where north is in the dir of phi)
    def create_nw
      @pos.subtract_vector(@n.scale @w/2.0).add_vector(@u.scale @l/2.0)
    end

    # position of southeast corner of agent (where north is in the dir of phi)
    def create_se
      @pos.add_vector(@n.scale @w/2.0).subtract_vector(@u.scale @l/2.0)
    end

    # poisiton of southwest corner of agent (where north is in the dir of phi)
    def create_sw
      @pos.subtract_vector(@n.scale @w/2.0).subtract_vector(@u.scale @l/2.0)
    end

    def nw_tire_pts
      # get the center of the tire
      c = @nw.subtract_vector(@u.scale(@tl/2)).subtract_vector(@n.scale(@tw/2))

      # get the scaled heading and normal vectors for the tire
      tire_u = @u.rotate(@delta).scale(@tl/2.0)
      tire_n = @n.rotate(@delta).scale(@tw/2.0)
      
      [ c.add_vector(tire_u).subtract_vector(tire_n),
        c.add_vector(tire_u).add_vector(tire_n),
        c.subtract_vector(tire_u).add_vector(tire_n),
        c.subtract_vector(tire_u).subtract_vector(tire_n) ]
    end

    def ne_tire_pts
      # get the center of the tire
      c = @ne.subtract_vector(@u.scale(@tl/2)).add_vector(@n.scale(@tw/2))

      # get the scaled heading and normal vectors for the tire
      tire_u = @u.rotate(@delta).scale(@tl/2.0)
      tire_n = @n.rotate(@delta).scale(@tw/2.0)
      
      [ c.add_vector(tire_u).subtract_vector(tire_n),
        c.add_vector(tire_u).add_vector(tire_n),
        c.subtract_vector(tire_u).add_vector(tire_n),
        c.subtract_vector(tire_u).subtract_vector(tire_n) ]
    end
    
    def se_tire_pts
      # get the scaled heading and normal vectors for the tire (since it's a
      # back tire, these are aligned with the car as a whole).
      u_scale = @u.scale @tl
      n_scale = @n.scale @tw
      
      [ @se.add_vector(u_scale).add_vector(n_scale),
        @se.add_vector(u_scale),
        @se,
        @se.add_vector(n_scale) ]
    end

    def sw_tire_pts
      # get the scaled heading and normal vectors for the tire (since it's a
      # back tire, these are aligned with the car as a whole).
      u_scale = @u.scale @tl
      n_scale = @n.scale @tw
      
      [ @sw.add_vector(u_scale),
        @sw.add_vector(u_scale).subtract_vector(n_scale),
        @sw.subtract_vector(n_scale),
        @sw ]
    end

    

    def move t
      if @delta.abs < 0.01
        move_straight t
      else
        move_curved t
      end
    end
    
    # Move the agent in a straight path as if time t (in seconds) has
    # elapsed. Note: this should only be used when delta is very small.
    def move_straight t
      update_pos(@pos.add_vector(@u.scale t * @speed))
    end

    # Move the agent in a curved path as if time t (in seconds) has
    # elapsed. Note: this should be used instead of move_straight whenever delta
    # is sizeable.
    def move_curved t
      r = @l / Math.sin(@delta.abs)      
      theta = @speed / (2.0*Math::PI) * t

      # puts "#{pos}: r = %.5f, theta = %.5f" % [r, theta*180.0/Math::PI]

      rotate theta
    end

    # Rotates the agent by arclength theta a. The agent is rotated such that the
    # back right (or left) tire is pivoted by theta along the point where normal
    # lines from the back right (or left) tire and front right (or left) tire
    # meet. Rotated to the right if delta>0, to the left if delta<0.
    def rotate theta
      r = @l / Math.sin(@delta.abs)
      tire_d_mag = 2.0 * r * Math.sin(theta/2)
      tire_d_ang = theta / 2.0

      # translate the car so that the southwest tire is moved to the correct
      # position.
      update_pos(@pos.add_vector(Vector.from_mag_dir(tire_d_mag, tire_d_ang)))

      # rotate the car about the southwest or southeast tire, depending on which
      # way it's turning
      if @delta > 0
        update_pos(@pos.rotate(@sw.add_vector(@n.scale(r)), theta))
      else
        update_pos(@pos.rotate(@se.subtract_vector(@n.scale(r)), theta))
      end

      # update phi to reflect the rotation
      update_phi @phi + theta
    end
    
    # Causes the agent to accelerate or decellerate at a rate
    # determined by x.
    # @param x Float the acceleration, in range [-1, 1]
    def accelerate x
      Thread.new do
        loop do
          @speed += x / 0.01
          sleep 0.01
        end
      end
    end

    def go_crazy
      Thread.new do
        loop do
          @delta += (rand - 0.5) * Math::PI
          sleep 1
        end
      end
    end
  end
end
