module Driving
  class DynamicalAgent < ClientAgent

    # Dynamical navigation parameters
    PARAMS = {
      :m => 2,          # general scaling of repeller
      :d0 => 0.01,      # distance scaling factor
      :c1 => 1,
      :c2 => 1,
      :a => 20,         # target attractor scaling factor
      :a_tar => 1,
      :g_tar_obs => 1,
      :sigma => 1,      # safety margin for windower
      :h1 => 10         # slope of windower
    }

    # Mode that the agent starts in
    START_MODE = :start
    # Mode reached when the agent reaches an intersection, which means
    # that it needs to choose which direction it's going to travel in
    INTERSECTION_MODE = :intersection
    # Mode reached when the agent reaches a road end that is not an
    # intersection, which means that there is no choice of where to go
    # next.
    TURN_MODE = :turn
    # Normal operating mode of the agent; it just dynamically
    # navigates towards the current target.
    NORMAL_MODE = :normal

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

      m = PARAMS[:m]
      d0 = PARAMS[:d0]
      # c1 = PARAMS[:c1]
      # c2 = PARAMS[:c2]
      a = PARAMS[:a]
      sigma = PARAMS[:sigma]
      h1 = PARAMS[:h1]
      # a_tar = PARAMS[:a_tar]
      # g_tar_obs = PARAMS[:g_tar_obs]


      # each obs is of the form [dm, psi, d_psi]
      obs_list = perceive_obs

      tar_pos = @target[0]
      tar_size = @target[1]
      
      psi_tar = (tar_pos - pos).dir

      # w_tar, w_obs = get_weights(phi, psi_tar, obs_list, weights, timestep, d0,
      #                            c1, c2, a, h1, sigma, a_tar, g_tar_obs)
      # agent.weights = [w_tar, w_obs]
      

      f_obs = obs_list.collect{|obs_i| m*f_obs_i(@phi, obs_i, d0, sigma, h1)}
      if false # rand < 0.1
        puts "a: r% .2f % .4f, r% .2f % .4f" %
          [@obs[0][1], ((@obs[0][0] - @pos).dir - @phi)/Math::PI,
           @obs[1][1], ((@obs[1][0] - @pos).dir - @phi)/Math::PI]
        puts "f: r% .2f % .4f, r% .2f % .4f" % [@obs[0][1], f_obs[0],
                                                @obs[1][1], f_obs[1]]
        puts f_obs.reduce(:+)
        puts ""
      end
      f_obs = f_obs.reduce(:+)


      f_tar(phi, a, psi_tar) + f_obs.to_f
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
      when :initial, :dest_change
        @mode = START_MODE
        # get constant information
        @map = Map.new(msg[:map]) if msg[:map]
        @dest = Point.new(*msg[:dest])
        @radius = DYNAMICAL_AGENT_RADIUS
        @length = msg[:l] if msg[:l]
        @width = msg[:w] if msg[:w]

        # need to set this so it's ready to use next time
        @curr_time = Time.now
        
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
        @curr = find_curr_road
          
        # prepare and send the response

        if @curr
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
        else
          resp = {:phi => @phi, :renders => []}
        end
        
        send resp
      end
    end

    def mode= mode
      puts "Mode transitioned from #{@mode} to #{mode}"
      @mode = mode
    end

    # this function defines the transition conditions between the
    # states of the FSA that controls the behavior of the agent
    def mode_transitions
      case @mode
      when START_MODE
        facing, _ = facing_node
        if facing
          @target = create_tar facing.pos
          self.mode = NORMAL_MODE 
        end
      when NORMAL_MODE
        facing, other = facing_node
        if facing.pos.dist(@pos) < ROAD_WIDTH
          if facing.neighbors.size > 2
            self.mode = INTERSECTION_MODE
            @target = choose_tar
          else
            self.mode = TURN_MODE
            @target = create_tar((facing.neighbors - Set[other]).first.pos)
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

    # Creates an object on each side of the current road. This should be
    # sufficient for keeping the agent from veering off the side of the road.
    #
    # Here obstacles are just arrays of position and radius, since these are
    # their intrinsic attributes; in perceive_obs we compute the parameters of
    # the obstacles needed for the dynamical navigation calculations.
    def create_obs
      facing, other = facing_node
      road_norm = (facing.pos-@pos).normal_vector
      # the line that goes from the agent's pos in the direction of
      # the vector normal to the road a sufficiently long distance
      # such that it will definitely intersect with one of the road
      # edges; this lets us figure out which one is the edge on the
      # right side of the road, which is the one we want as an obstacle.
      norm_line = LineSegment.new(@pos, @pos + road_norm * 100)
      # line segment that goes down the center of the road
      center_line = LineSegment.new(@curr.n0.pos, @curr.n1.pos)
      # check if we're on the wrong side of the road for some reaons;
      # if so, we want to disable the center line obstacle so we can
      # get back onto the right side
      road_edge = @curr.walls.find{|w|
        w.intersection norm_line
      }
      obs = []
      if norm_line.intersection center_line
        center_line = nil
        w = (@curr.walls - Set[road_edge]).first
        # make it larger than a normal obs so that it pushes the agent
        # back into the proper lane
        obs << create_obs_from_wall(w, @radius*10)
      end
      obs += [road_edge, center_line].reject{|x| x.nil?}.collect do |w|
        create_obs_from_wall w
      end
    end

    def create_obs_from_wall w, r = @radius
      facing, other = facing_node
      unit = w.unit_from_pt(@pos)
      dist = w.dist_to_pt(@pos)
      r = 2*r / dist
      par_comp = (facing.pos-other.pos).normalize*@length/2.0
      perp_comp = unit*(dist+r)
      [@pos + perp_comp + (DYNAMICAL_OBSTACLES_AHEAD ? par_comp : Vector.new(0,0)), r]
    end

    # If the agent is on a road with (facing, other) = (n0, n1), this
    # function chooses the target t from the set {t | t != n1, t is a neighbor
    # of n0} such that if u is the vector from the agent to the
    # destination and v is the angle from n0 to t, (u-v).abs is
    # minimized. Basically, we want to take the road that seems like
    # it might get us to the destination taking into account only
    # purely local conditions.
    def choose_tar
      facing, other = facing_node
      dest_dir = (@dest - @pos).dir
      t = (facing.neighbors - Set[other]).min_by{|t|
        (dest_dir - (t.pos - facing.pos).dir).abs
      }
      create_tar t.pos
    end

    # Creates a target at the specified point
    def create_tar p
      road_norm = (p-@pos).normal_vector.normalize
      [p + road_norm * (ROAD_WIDTH/2), @radius]
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
      [@curr.n0, @curr.n1].sort_by{|n|
        ((n.pos - @pos).dir - @phi).abs
      }
    end

    def socket; @socket; end
    
  end
end
