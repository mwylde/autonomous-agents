module Driving
  class DynamicalAgent < ClientAgent

    CIRCLE_RADIUS = 1.0

    # Parameters
    D0 = 1.0
    SIGMA = 1.0
    H1 = 1.0
    A = 1.0

    def f_tar tar, a = A
      psi = (tar[0] - @pos).dir
      
      -a * Math.sin(@phi-psi)
    end

    def repeller psi, d_psi
      ((@phi-psi)/d_psi) * Math.exp((1-(@phi-psi)/d_psi).abs)
    end

    def f_obs_i obs_i, d0 = D0, sig = SIGMA, h1 = H1
      obs_c, obs_r = obs_i
      dm = @pos.dist(obs_c) - obs_r

      psi = (obs_c - @pos).dir

      d_psi = 1.0 # ???

      d_i = dist_scale dm, d0
      w_i = windower h1, psi, d_psi, sig
      r_i = repeller psi, d_psi
      
      d_i * w_i * r_i
    end

    def delta_dot
      dd = f_tar @tar
      @obs.each do |o|
        dd += f_obs_i o
      end
      return dd
    end

    def windower h1, psi, d_psi, sigma
      0.5 * (Math.tanh(h1*(Math.cos(@phi-psi) - Math.cos(d_psi + sigma))) + 1)
    end

    def dist_scale dm, d0
      Math.exp(-1*(dm/d0))
    end
    
    def handle_msg msg
      @pos = Point.new(*msg[:pos])
      @phi = msg[:phi]
      @delta = msg[:delta]
      @delta_speed = msg[:delta_speed]
      @speed = msg[:speed]
      @accel = msg[:accel]
      @curr_road = msg[:curr_road]
      @obs = create_obs

      
      case msg[:type]
      when :initial
        @map = Map.new(msg[:map])
        @dest = msg[:dest]
        @bound_r = msg[:bound_r]
        @tar = create_tar
      end

      resp = {}
      
      renders = ["@g.set_color Color.red"]
      @obs.each do |o|
        c, r = o
        cx, cy = c.to_a
        renders << "circle Point.new(#{cx}, #{cy}), #{r}"
      end

      c, r = @tar
      cx, cy = c.to_a
      renders << "@g.set_color Color.blue"
      renders << "circle Point.new(#{cx}, #{cy}), #{r}"
      
      resp[:renders] = renders

      time_step = 0.05 # FIXME really this should be calculated as the differenc
                       # in time between the last messaeg and the current one
      new_delta = @delta + delta_dot * time_step

      send resp
    end

    def create_obs
      units = @curr_road.units_to_walls @pos
      dists = @curr_road.dists_to_walls @pos

      @curr_road.walls.collect do |w|
        id = w.object_id
        [@pos + units[id] * (ROAD_WIDTH + CIRCLE_RADIUS), CIRCLE_RADIUS]
      end
    end

    def create_tar
      [@pos + Vector.from_mag_dir(20, @phi), CIRCLE_RADIUS]
    end

    def socket; @socket; end
  end
end
