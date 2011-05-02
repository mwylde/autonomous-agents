module Driving
  # A SimpleAgent is an agent used for testing purposes that does not try to
  # perform any kind of navigation. 
  class SimpleAgent < ClientAgent
    EPSILON = 0.01
    
    def handle_msg msg
      @pos = Point.new(*msg[:pos])
      @phi = msg[:phi]
      @delta = msg[:delta]
      @delta_speed = msg[:delta_speed]
      @speed = msg[:speed]
      @accel = msg[:accel]

      puts "#{@pos}, Delta #{@delta}, Spd #{@speed}, Accel #{@accel}"

      resp = {}
      
      case msg[:type]
      when :initial
        # @map = Map.new(msg[:map])
        resp[:accel] = 0.1
        resp[:delta] = Math::PI / 4
        @target_spd = 1.0
      end

      resp[:accel] = 0.1 if @speed < @target_spd - EPSILON
      resp[:accel] = -0.1 if @speed > @target_spd + EPSILON
      resp[:accel] = 0.0 if @speed > @target_spd - EPSILON &&
                            @speed < @target_spd + EPSILON

      send resp
    end
        
    
    # # Causes the agent to accelerate or decellerate at a rate
    # # determined by x for a time period t.
    # # @param x Float the acceleration, in meters per second per second.
    # # @param t Float the time, in seconds, to accelerate for.
    # def accelerate x, t
    #   curr_time = Time.now
      
    #   Thread.new do
    #     until Time.now > start_time + t do
    #       last_time = curr_time
    #       curr_time = Time.now
    #       @speed += x * (curr_time - last_time)
    #       @speed = 0 if @speed < 0
    #       sleep 1.0 / STATE_UPDATE_FREQUENCY
    #     end
    #   end
    # end

    # # Causes the agent to accelerate or decellerate for a time period t at a
    # # rate such that it reaches speed x.
    # # @param x Float the target speed, in meters per second, to reach at the
    # # end.
    # # @param t Float the time, in seconds, to accelerate for.
    # def accelerate_to x, t
    #   rate = (x - @speed) / t
    #   @speed = 0 if @speed < 0
    #   accelerate rate, t
    # end

    # # Causes the agents' wheels (angle delta) at a rate determined by x, for a
    # # period of time t.
    # # @param x Float the speed, in radians per second, to turn the wheel.
    # # @param t Float the time, in seconds, to turn the wheel
    # def wheel_turn x, t
    #   predicted_end_delta = @delta + x*t
    #   unless predicted_end_delta.abs < Math::PI/2
    #     raise "End wheel position must be in range [-pi/2, pi/2]"
    #   end

    #   curr_time = Time.now
      
    #   Thread.new do
    #     until Time.now > start_time + t do
    #       last_time = curr_time
    #       curr_time = Time.now
    #       @delta += x * (curr_time - last_time)
    #       sleep 1.0 / STATE_UPDATE_FREQUENCY
    #     end
    #   end
    # end

    # # Causes the agents' wheels (angle delta) to turn to a position x in a
    # # period of time t.
    # # @param x Float the angle to turn the wheels to.
    # # @param t Float the time it should take to turn the wheels.
    # def wheel_turn_to x, t
    #   unless x.abs < Math::PI/2
    #     raise "Target wheel position must be in range [-pi/2, pi/2]"
    #   end
        
    #   rate = (x - @delta) / t
    #   wheel_turn rate, t
    # end
      

    # def turn_left
    #   Thread.new do
    #     accelerate_to 0.5, 5
    #     sleep 3
    #     accelerate_to 0.1, 1
    #     sleep 1
    #     wheel_turn_to -Math::PI/4, 0.5
    #     sleep 0.5
    #     wheel_turn_to 0, 0.5
    #     sleep 0.5
    #     accelerate_to 0.5, 1
    #     sleep 1
    #     accelerate_to 0, 5
    #   end
    # end

    # def go_crazy
    #   @speed = 0.5
    #   Thread.new do
    #     loop do
    #       @delta = (rand - 0.5) * Math::PI/2
    #       sleep 5
    #     end
    #   end
    # end

    # def go_straight
    #   @speed = 0.5
    #   @delta = 0.0
    # end

    def socket; @socket; end
  end
end
