module Driving
  class DynamicalAgent
    def f_tar phi, a, psi_tar
      -a * Math.sin(phi-psi_tar)
    end

    def repeller phi, psi, d_psi
      ((phi-psi)/d_psi) * Math.exp((1-(phi-psi)/d_psi).abs)
    end

    def f_obs_i phi, obsi, d0, sig, h1
      dm, psi, d_psi = obsi

      d_i = dist_scale dm, d0
      w_i = windower h1, phi, psi, d_psi, sig
      r_i = repeller phi, psi, d_psi
      
      d_i * w_i * r_i
    end

    def windower h1, phi, psi, d_psi, sigma
      0.5 * (Math.tanh(h1*(Math.cos(phi-psi) - Math.cos(d_psi + sigma))) + 1)
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
      
      case msg[:type]
      when :initial
        @map = Map.initialize(msg[:map])
        @dest = msg[:dest]
      end

      
    end
  end
end
