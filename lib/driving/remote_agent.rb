module Driving
  # RemoteServerAgent is a subclass of ServerAgent with extra methods
  # for dealing with ClientAgents. 
  class RemoteServerAgent < ServerAgent
    attr_reader :initial_pos
    include Communicator

    def initialize socket, server, *agent_params
      super *agent_params
      @socket = socket
      @server = server
      self.pos = @map.nodes.to_a.choice.pos
      curr = @map.closest_node @pos
      facing = curr.neighbors.to_a.choice
      # displace a bit along the vector from current position to
      # facing so that we're not directly on a node
      self.phi = (facing.pos - @pos).dir

      # we want to displace along the norm vector so that it ends up
      # in a lane rather than the center of the road
      self.pos = @pos + @u*3 + @n.normalize * (ROAD_WIDTH/2)
      
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
      @initial_pos = @pos
      @dest = dest_node.pos
      initial = {
        :type => :initial,
        :map => @map.to_hash,
        :dest => @dest.to_a,
      }
      send initial.merge(self.to_hash)
    end

    def new_dest p
      @dest = p
      msg = {
        :type => :dest_change,
        :dest => @dest.to_a
      }
      @paused = false
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
        msg = {
          :type => :unpause
        }
        send msg.merge(self.hash)
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
      self.delta = msg[:delta] if msg[:delta]
      @accel = msg[:accel] if msg[:accel]
      # cheating
      self.phi = msg[:phi] if msg[:phi]
      @renders = msg[:renders] if msg[:renders]
      puts "delta = #{@delta}; accel = #{@accel}" if rand < 0.01
      send(self.to_hash.merge({:type => :update}))
    end
  end
end
