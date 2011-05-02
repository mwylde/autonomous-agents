module Driving
  class DynamicalAgent < ClientAgent

    PARAMS = {
      :d0 => 1,
      :c1 => 1,
      :a => 1,
      :sigma => 1,
      :a_tar => 1,
      :g_tar_obs => 1,
      :h1 => 1
    }

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

    def phi_dot
      # We're treating phi as the heading direction. Since we're dealing with
      # cars, it's not exactly clear what we should be using as a heading
      # direction. It might turn out that delta is a better measure of the car's
      # heading direction, but using phi makes sense because phi is the
      # instantaneous direction the car is heading.
      phi = @phi
      pos = @pos
      size = @size

      # weights = agent.weights

      d0 = PARAMS[:d0]
      c1 = PARAMS[:c1]
      a = PARAMS[:a]
      sigma = PARAMS[:sigma]
      a_tar = PARAMS[:a_tar]
      g_tar_obs = PARAMS[:g_tar_obs]
      h1 = PARAMS[:h1]

      # each obs is of the form [dm, psi, d_psi]
      obs_list = perceive_obs

      tar_pos = @target[0]
      tar_size = @target[1]
      
      psi_tar = (tar_pos - pos).dir

      # w_tar, w_obs = get_weights(phi, psi_tar, obs_list, weights, timestep, d0,
      #                            c1, c2, a, h1, sigma, a_tar, g_tar_obs)
      # agent.weights = [w_tar, w_obs]
      
      f_obs = obs_list.collect{|obs_i| f_obs_i(@phi, obs_i, d0, sigma, h1)}
      if rand < 0.01
        puts "a: r% .2f % .4f, r% .2f % .4f" %
          [@obs[0][1], ((@obs[0][0] - @pos).dir - @phi)/Math::PI,
           @obs[1][1], ((@obs[1][0] - @pos).dir - @phi)/Math::PI]
        puts "f: r% .2f % .4f, r% .2f % .4f" % [@obs[0][1], f_obs[0],
                                                @obs[1][1], f_obs[1]]
        puts f_obs.reduce(:+)
        puts ""
      end
      f_obs = f_obs.reduce(:+)


      f_tar(phi, a, psi_tar) + f_obs
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
      raise "Agent colliding with obstacle" if ((r0+r1)/d).abs > 1
      [Math.asin((r0 + r1)/d), Math::PI/2-0.0001].min
    end

    def handle_msg msg
      case msg[:type]
      when :initial
        # get constant information
        @map = Map.new(msg[:map])
        @dest = msg[:dest]
        @radius = DYNAMICAL_AGENT_RADIUS
        @length = msg[:l]
        @width = msg[:w]

        # need to set this so it's ready to use next time
        @curr_time = Time.now
        
        # send initial response
        send({
          :phi => msg[:phi] + Math::PI / 8.0,
          :accel => 1.0,
          :delta => 0.0
        })
      else
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
        @curr_road = find_curr_road
        if @curr_road.nil?
          new_phi = @phi
          @obs = []
        else
          @facing = facing_node[0]
          @target = create_tar # msg[:dest] <- put in when want to use real tar
          @obs = create_obs

          @last_time = @curr_time
          @curr_time = Time.now
          begin
            new_phi = @phi + phi_dot * (@curr_time - @last_time)
          rescue
            puts $!
            new_phi = @phi
          end
        end
          
        # prepare and send the response

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
        
        send resp
      end
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
        r = 2*@radius / dists[id]
        facing, other = facing_node
        par_comp = (facing.pos-other.pos).normalize*@length/2.0
        perp_comp = units[id]*(dists[id]+r)
        [@pos + perp_comp + (DYNAMICAL_OBSTACLES_AHEAD ? par_comp : Vector.new(0,0)), r]
      end
    end

    def create_tar
      [@facing.pos, @radius]
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

    # Determines which node of the current road the agent is facing; this
    # depends on the position and the heading direction (phi). Returned as an
    # array where the first element is the facing node and the second is the
    # other node.
    def facing_node
      [@curr_road.n0, @curr_road.n1].sort_by{|n|
        ((n.pos - @pos).dir - @phi).abs
      }
    end

    def socket; @socket; end
    
  end
end
