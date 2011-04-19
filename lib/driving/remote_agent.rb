module Driving
  class RemoteServerAgent < ServerAgent
    include Communicator

    def initialize socket, *agent_params
      super *agent_params
      @socket = socket
      map = @map.to_hash
      dest_node = @map.closest_node @pos
      # pick a random dest that is relatively accessible from the
      # current position
      last = @dest
      while rand > 0.001
        choices = dest_node.neighbors.to_a
        choices.delete last
        dest_node = choices.choice #get random
        last = dest_node
      end
      @dest = dest_node.pos
      facing = dest_node.neighbors.to_a.choice
      @phi = (facing.pos - @pos).dir
      initial = {
        :type => :initial,
        :map => @map.to_hash,
        :dest => @dest.to_a
      }
      send initial.merge(self.to_hash)
    end
    
    def run
      super
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
      @delta = msg[:delta] if msg[:delta]
      @accel = msg[:accel] if msg[:accel]
      @renders = msg[:renders] if msg[:renders]
      puts "delta = #{@delta}; accel = #{@accel}" if rand < 0.01
      send(self.to_hash.merge({:type => :update}))
    end
  end
end
