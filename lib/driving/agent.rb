module Driving
  class ServerAgent
    attr_reader :id, :pos, :phi, :delta, :delta_speed, :speed, :accel, :w, :h

    # Creates a default agent with positional parameters set to 0; requires
    # width and heigh tspecification
    def initialize(id, w, h, x = 0, y = 0, phi = 0, delta = 0,
                   delta_speed = 0, speed = 0, accel = 0)
      @id = id
      @pos = Point.new(x, y)
      @phi = phi
      # delta > 0 means turning to the right
      @delta = delta
      @delta_speed = delta_speed
      @speed = speed
      @accel = accel
      @w = w
      @h = h
    end

    def to_hash
      {
        :pos => [@pos.x, @pos.y],
        :phi => phi,
        :delta => delta,
        :delta_speed => delta_speed,
        :speed => speed,
        :accel => accel
      }
    end

    # Starts the update loop which periodically updates the state
    # variables. Spawns a thread, so non-blocking.
    # @param start_time Time the start time of the simulation 
    def run start_time
      Thread.new do
        move(Time.now - start+time)
      end
    end

    # unit vector pointing in the direction of phi
    def u
      Vector.new(Math.cos(phi), Math.sin(phi))
    end

    # unit vector pointing normal to u
    def n
      u.normal_vector
    end
      
    # position of northeast corner of agent (where north is in the dir of phi)
    def ne
      @pos.add_vector(n.scale -@w/2.0).add_vector(u.scale @h/2.0)
    end

    # position of northwest corner of agent (where north is in the dir of phi)
    def nw
      @pos.add_vector(n.scale @w/2.0).add_vector(u.scale @h/2.0)
    end

    # position of southeast corner of agent (where north is in the dir of phi)
    def se
      @pos.add_vector(n.scale @w/2.0).add_vector(u.scale -@h/2.0)
    end

    # poisiton of southwest corner of agent (where north is in the dir of phi)
    def sw
      @pos.add_vector(n.scale -@w/2.0).add_vector(u.scale -@h/2.0)
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
      @pos.add_vector(u.scale t)
    end

    # Move the agent in a curved path as if time t (in seconds) has
    # elapsed. Note: this should be used instead of move_straight whenever delta
    # is sizeable.
    def move_curved t
      r = @h / Math.sin(@delta.abs)      
      theta = @vel / (2.0*Math::PI) * t

      rotate theta
    end

    # Rotates the agent by arclength theta a. The agent is rotated such that the
    # back right (or left) tire is pivoted by theta along the point where normal
    # lines from the back right (or left) tire and front right (or left) tire
    # meet. Rotated to the right if delta>0, to the left if delta<0.
    def rotate theta
      r = @h / Math.sin(@delta.abs)
      tire_d_mag = 2.0 * r * Math.sin(theta/2)
      tire_d_ang = theta / 2.0

      # translate the car so that the southwest tire is moved to the correct
      # position.
      @pos.add_vector!(Vector.new(tire_d_mag, tire_d_ang, mag_dir=True))

      # rotate the car about the southwest or southeast tire, depending on which
      # way it's turning
      if @delta > 0
        @pos.rotate sw, theta
      else
        @pos.rotate se, theta
      end

      # update phi to reflect the rotation
      @phi.rotate theta
    end
    
    # Causes the agent to accelerate or decellerate at a rate
    # determined by x.
    # @param x Float the acceleration, in range [-1, 1]
    def accelerate x
    end

    # Causes the agent to steer to the right or left
    # @param x Float amount to turn, in range [-1, 1]
    def turn x
    end

    def update
    end

  end
end
