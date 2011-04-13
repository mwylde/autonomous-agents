module Driving
  class RemoteServerAgent < ServerAgent
    include Communicator

    def initialize socket, *agent_params
      super *agent_params
      @socket = socket
      initial = {
        :map => self.to_hash,
        :dest => @map.nodes.to_a.choice.pos #random element
      }
      send initial.merge(self.to_hash)
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
      @delta = msg[:delta]
      @accel = msg[:accel]
      send self.to_hash
    end
  end
end
