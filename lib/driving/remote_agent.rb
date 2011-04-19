module Driving
  class RemoteServerAgent < ServerAgent
    include Communicator

    def initialize socket, *agent_params
      super *agent_params
      @socket = socket
      @pos = @map.nodes.to_a.choice.pos
      curr = @map.closest_node @pos
      facing = curr.neighbors.to_a.choice
      puts facing.inspect
      # pick a random dest that is relatively accessible from the
      # current position
      dest_node = facing
      seen = Set[curr]
      while rand > 0.001 && dest_node.neighbors.size > 1
        puts dest_node.inspect
        # choices = dest_node.neighbors.to_a
        # choices.delete last
        seen << dest_node
        dest_node = dest_node.neighbors.max_by{|n| seen.include?(n) ? -1 :  n.neighbors.size}
      end
      @dest = dest_node.pos
      update_phi (facing.pos - @pos).dir
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
      # cheating
      update_phi msg[:phi] if msg[:phi]
      @renders = msg[:renders] if msg[:renders]
      puts "phi = #{@phi}; accel = #{@accel}" if rand < 0.01
      send(self.to_hash.merge({:type => :update}))
    end
  end
end
