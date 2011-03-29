module Driving
  class Agent
    attr_reader :x, :y, :phi, :velocity, :acceleration

    # Creates a default agent with all parameters set to 0
    def initialize
      @x, @y, @phi, @velocity, @acceleration = [0]*5
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
