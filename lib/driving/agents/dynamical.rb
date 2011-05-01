module Driving
  class DynamicalAgent < ClientAgent

    def f_tar phi, a, psi_tar
      -a * Math.sin(phi - psi_tar)
    end

    def repeller phi, psi, d_psi
      frac = (phi - psi) / d_psi
      frac * Math.exp(1 - frac.abs)
    end

    def windower h1, phi, psi, d_psi, sigma
      0.5 * (Math.tanh(h1*Math.cos(phi-psi)-Math.cos(d_psi+sigma))+1)
    end

    def dist_scale dm, d0
      Math.exp(-1 * dm/d0)
    end

    def f_obs_i phi, obs_i, d0, sig, h1
      # unpack obs attributes
      dm, psi, d_psi = obs_i

      d_i = dist_scale dm, d0
      w_i = windower h1, phi, psi, d_psi, sig
      r_i = repeller phi, psi, d_psi
      d_i * w_i * r_i
    end

    def delta_dot
      # We're treating phi as the heading direction. Since we're dealing with
      # cars, it's not exactly clear what we should be using as a heading
      # direction. It might turn out that delta is a better measure of the car's
      # heading direction, but using phi makes sense because phi is the
      # instantaneous direction the car is heading.
      phi = @phi
      pos = @pos
      size = @size

      # weights = agent.weights

      d0 = @params[:d0]
      c1 = @params[:c1]
      c2 = @params[:a]
      sigma = @params[:sigma]
      a_tar = @params[:a_tar]
      g_tar_obs = @params[:g_tar_obs]
      h1 = @params[:h1]

      # each obs is of the form [dm, psi, d_psi]
      obs_list = perceive_obs

      tar_pos = @target[0]
      tar_size = @target[1]
      
      psi_tar = (tar_pos - pos).dir

      # w_tar, w_obs = get_weights(phi, psi_tar, obs_list, weights, timestep, d0,
      #                            c1, c2, a, h1, sigma, a_tar, g_tar_obs)
      # agent.weights = [w_tar, w_obs]
      
      f_obs = obs_list.collect{|obs_i| f_obs_i(phi, obs_i, d0, sigma, h1)}
      f_obs = f_obs.reduce{|sum, x| sum + x}

      # w_tar.abs*f_tar + w_obs.abs*f_obs + 0.01*(rand-0.5)
    end

    # Obstacles are ordinarily stored (in @obs) as arrays containing position
    # and radius. Here we compute the parameters relevant to the obstacle needed
    # for dynamical navigation calculations; each obstacle returned is an array
    # of form [dm, psi, d_psi]
    def perceive_obs
      @obs.collect do |obs|
        obs_pos = obs[0]
        obs_radius = obs[1]

        dm = @pos.dist(obs_pos) - @radius - obs_radius
        psi = (obs_pos - @pos).dir
        d_psi = subtended_angle(@pos, @radius, obs_pos, obs_radius)
        [dm, psi, d_psi]
      end
    end

    # Computes the angle subtended by two circles, given their positions and
    # radii. This utilizes the fact that the subtended angle forms similar
    # triangles.
    def subtended_angle(p0, r0, p1, r1)
      d = p0.dist p1
      Math.asin((r0 + r1)/d)
    end

    def handle_msg msg
      
      # Get the data from the message
      
      @pos = Point.new(*msg[:pos])
      @phi = msg[:phi]
      @delta = msg[:delta]
      @delta_speed = msg[:delta_speed]
      @speed = msg[:speed]
      @accel = msg[:accel]
      @curr_road = Road.from_hash msg[:curr_road]
      @facing = get_facing_node
      @target = create_tar # msg[:dest] <- put in when want to use real tar

      resp = {}
      
      case msg[:type]
      when :initial
        @map = Map.new(msg[:map])
        @dest = msg[:dest]
        @radius = AGENT_LENGTH / 2.0
        resp[:speed] = 0.5
        resp[:accel] = 0.1
        resp[:delta] = 0.1
      end

      # Create appropriate obstacles, and choose the new delta.

      @params = {
        :d0 => 1,
        :c1 => 1,
        :a => 1,
        :sigma => 1,
        :a_tar => 1,
        :g_tar_obs => 1,
        :h1 => 1
      }
      
      # Create the obstacles (they are created dynamically to follow the car
      # along the side of the road.
      @obs = create_obs

      @last_time = @curr_time ? @curr_time : Time.now
      @curr_time = Time.now
      time_step = @curr_time - @last_time
      resp[:delta] = @delta + delta_dot * time_step

      # FIXME: we should have a better to handle avoiding extreme delta values;
      # maybe some form of repeller?
      resp[:delta] = -Math::PI/2.0 if resp[:delta] < -Math::PI/2.0
      resp[:delta] =  Math::PI/2.0 if resp[:delta] >  Math::PI/2.0

      # Render the obstacles and target for this agent.
      
      renders = ["@g.set_color Color.red"]
      @obs.each do |o|
        c, r = o
        renders << "circle Point.new(#{c.x}, #{c.y}), #{r}"
      end

      c = @target[0]
      r = @target[1]
      renders << "@g.set_color Color.blue"
      renders << "circle Point.new(#{c.x}, #{c.y}), #{r}"
      
      resp[:renders] = renders

      # Send the final response
      
      send resp
    end

    # Creates an object on each side of the current road. This should be
    # sufficient for keeping the agent from veering off the side of the road.
    #
    # Here obstacles are just arrays of position and radius, since these are
    # their intrinsic attributes; in perceive_obs we compute the parameters of
    # the obstacles needed for the dynamical navigation calculations.
    def create_obs
      units = @curr_road.units_to_walls @pos
      dists = @curr_road.dists_to_walls @pos

      @curr_road.walls.collect do |w|
        id = w.object_id
        r = @radius / dists[id]
        [@pos + units[id] * (dists[id] + r), r]
      end
    end

    def create_tar
      [@facing.pos, @radius]
    end

    # Determines which node of the current road the agent is facing; this
    # depends on the position and the heading direction (phi).
    def get_facing_node
      ang0 = ((@curr_road.n0.pos - @pos).dir - @phi).abs
      ang1 = ((@curr_road.n1.pos - @pos).dir - @phi).abs
      ang0 < ang1 ? @curr_road.n0 : @curr_road.n1
    end      

    def socket; @socket; end
    
  end
end
