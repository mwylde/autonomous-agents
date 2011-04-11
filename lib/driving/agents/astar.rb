module Driving
  class AStarAgent < ClientAgent
    # calculates the best route from the current node to the
    # destination node using A*
    def astar
    end
    
    def handle_msg msg
      @pos = Point.new(*msg[:pos])
      @route = []
      case msg[:type]
      when :initial
        @map = Map.initialize(msg[:map])
        @dest = msg[:dest]
        # find cloest node to our current pos
        @curr, _ = @map.nodes.reduce([nil, 999999999999]){|best, n|
          dist = @pos.dist(n.pos)
          best[1] < dist ? best : [n, dist]
        }
        
      when :update
        # do stuff
      end
    end
  end
end
