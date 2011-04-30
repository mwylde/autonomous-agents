module Driving
  class DynamicalAgent < ClientAgent

    def f_tar phi, a, psi_tar
      -a * Math.sin(phi - psi_tar)
    end

    def R phi, psi, d_psi
      frac = (phi - psi) / d_psi
      frac * Math.exp(1 - Math.abs(frac))
    end

    def W h1, phi, psi, d_psi, sigma
      0.5 * (Math.tanh(h1*Math.cos(phi-psi)-Math.cos(d_psi+sigma))+1)
    end

    def D dm, d0
      Math.exp(-1 * dm/d0)
    end

    def F_obs_i phi, obs_i, d0, sig, h1
      # unpack obs attributes
      dm, psi, d_psi = obs_i

      D_i = D dm, d0
      W_i = W h1, phi, psi, d_psi, sig
      R_i = R phi, psi, d_psi
      D_i * W_i * R_i
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
      obs_list = @perceived_obs

      tar_pos, tar_size = @target
      
      psi_tar = (tar_pos - pos).dir

      # w_tar, w_obs = get_weights(phi, psi_tar, obs_list, weights, timestep, d0,
      #                            c1, c2, a, h1, sigma, a_tar, g_tar_obs)
      # agent.weights = [w_tar, w_obs]
      
      f_obs = obs_list.collect{|obs_i| f_obs_i(phi, obs_i, d0, sigma, h1)}.sum

      # (Math.abs(w_tar)*f_tar) + (Math.abs(w_obs)*f_obs) + 0.01*(rand-0.5)
    end

    def sense
      tar_pos, tar_size = @target

      @obs.collect do |obs|
        obs_pos = obs[0]
        obs_radius = obs[1]
        
        dm = @pos.dist(obs_pos) - @radius - obs_radius
        psi = (obs_pos - @pos).dir
        d_psi = subtended_angle(@pos, @radius, obs_pos, obs_radius)
        [dm, psi, d_psi]
      end
    end

    def subtended_angle(p0, r0, p1, r1)
      # FIXME: COMPUTE STUFF!
    end

    def handle_msg msg
      @pos = Point.new(*msg[:pos])
      @phi = msg[:phi]
      @delta = msg[:delta]
      @delta_speed = msg[:delta_speed]
      @speed = msg[:speed]
      @accel = msg[:accel]
      @curr_road = msg[:curr_road]
      @target = create_tar # msg[:target] <- put in when want to use real tar

      resp = {}
      
      case msg[:type]
      when :initial
        @map = Map.new(msg[:map])
        @dest = msg[:dest]
        @bound_r = msg[:bound_r]
        resp[:speed] = 0.5
        resp[:accel] = 0.1
        resp[:delta] = 0.1
      end

      @obs = create_obs
      
      renders = ["@g.set_color Color.red"]
      @obs.each do |o|
        c, r = o
        renders << "circle Point.new(#{c.x}, #{c.y}), #{r}"
      end

      c, r = @target
      renders << "@g.set_color Color.blue"
      renders << "circle Point.new(#{c.x}, #{c.y}), #{r}"
      
      resp[:renders] = renders

      time_step = 0.05 # FIXME really this should be calculated as the difference
                       # in time between the last message and the current one
      resp[:delta] = @delta + delta_dot * time_step

      send resp
    end

    # Creates an object on each side of the current road. This should be
    # sufficient for keeping the agent from veering off the side of the road.
    def create_obs
      units = @curr_road.units_to_walls @pos
      dists = @curr_road.dists_to_walls @pos

      @curr_road.walls.collect do |w|
        id = w.object_id
        r = @bound_r / dists[id]**2
        [@pos + units[id] * (dists[id] + r), r]
      end
    end

    def create_tar
      [@pos + Vector.from_mag_dir(20, @phi), @bound_r]
    end

    def socket; @socket; end
  end
end
