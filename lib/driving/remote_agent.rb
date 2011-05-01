module Driving
  class RemoteServerAgent < ServerAgent
    include Communicator

    def initialize socket, server, *agent_params
      super *agent_params
      @socket = socket
      @server = server
      @pos = @map.nodes.to_a.choice.pos
      curr = @map.closest_node @pos
      facing = curr.neighbors.to_a.choice
      puts facing.inspect
      # displace a bit along the vector from current position to
      # facing so that we're not directly on a node
      update_phi (facing.pos - @pos).dir
      update_pos @pos + @u*3
      
      # pick a random dest that is relatively accessible from the
      # current position
      dest_node = facing
      seen = Set[curr]
      while rand > 0.001 && dest_node.neighbors.size > 1
        puts dest_node.inspect
        # choices = dest_node.neighbors.to_a
        # choices.delete last
        seen << dest_node
        choices = dest_node.neighbors.reject{|n| seen.include?(n)}
        break if choices.size == 0
        dest_node = choices.max_by{|n| n.neighbors.size}
      end
      @dest = dest_node.pos
      initial = {
        :type => :initial,
        :map => @map.to_hash,
        :dest => @dest.to_a,
        :bound_r => 3.5/2.0 # FIXME this is a hack, should really be a
                            # reference, not a hardcoded value
      }
      send initial.merge(self.to_hash)
    end

    def new_dest p
      msg = {
        :type => :dest_change,
        :dest => @dest.to_a
      }
      send msg.merge(self.to_hash)
    end
    
    def run
      super
      Thread.new do
        read
      end
    end

    def close
      puts "Agent disconnected"
      @server.remove_agent self
    end

    def paused= p
      @paused = p
      if !p
        handle_msg @paused_msg if @paused_msg
      end
    end

    def socket
      @socket
    end

    def handle_msg msg
      if @paused
        @paused_msg = msg
        return
      end
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
