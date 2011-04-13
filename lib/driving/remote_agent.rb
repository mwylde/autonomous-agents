module Driving
  class RemoteServerAgent < ServerAgent
    include Communicator

    def initialize socket, *agent_params
      super *agent_params
      @socket = socket
      map = @map.to_hash
      dest = @map.nodes.to_a.choice.pos #random element
      initial = {
        :type => :initial,
        :map => @map.to_hash,
        :dest => dest.to_a
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
      # puts "delta = #{@delta}; accel = #{@accel}"
      send(self.to_hash.merge({:type => :update}))
    end
  end
end
