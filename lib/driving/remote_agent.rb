module Driving
  class RemoteServerAgent < ServerAgent
    include Communicator

    def initialize socket, *agent_params
      @socket = socket
      super *agent_params
    end
    
    def run
      Thread.new do
        read
      end
    end

    def socket
      @socket
    end

    def handle_msg msg
      # get actions from agents, which is choice of delta_speed (how
      # fast it's turning the wheel) and acceleration
      @delta_speed = msg[:delta_speed]
      @accel = msg[:accel]
      send self.to_hash
    end
  end
end
