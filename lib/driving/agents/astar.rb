require 'set'
java_import java.util.PriorityQueue

module Driving
  class AStarAgent < ClientAgent
    MAX_NODES_EXPANDED = 3500
    class AStarNode
      attr_accessor :state, :parent, :g, :h
      def initialize state, parent
        @state = state
        @parent = parent
        @g = 0
        @h = 0
      end

      def expand
        @state.neighbors.map{|n|
          AStarNode.new(n, self)
        }
      end
    end
    # calculates the best route from the current node to the
    # destination node using A*
    def astar
      fringe = PriorityQueue.new
      fringe.insert(AStarNode.new(@curr, nil))
      closed_states = Set.new
      nodes_expanded = 0
      unless fringe.isEmpty
        current = fringe.peek
        fringe.remove current # stupid java
        next if closed_states.include? current
        return current if current.state == @goal

        expanded = current.expand
        closed_states << current.state
        nodes_expanded += 1
        return nil if nodes_expanded > MAX_NODES_EXPANDED
        expanded.each{|successor|
          successor.g = current.g + current.state.pos.dist(successor.state.pos)
          successor.h = successor.state.pos.dist @goal.state.pos
          fringe.insert(successor)
        }
      end
    end

    def route
      node = astar
      route = []
      while node.parent
        route.unshift node.parent
        node = node.parent
      end
      route
    end

    def closest_node point, map
      map.nodes.reduce([nil, 999999999999]){|best, n|
        dist = point.dist(n.pos)
        best[1] < dist ? best : [n, dist]
      }[0]
    end
    
    def handle_msg msg
      @pos = Point.new(*msg[:pos])
      @route = []
      case msg[:type]
      when :initial
        @map = Map.initialize(msg[:map])
        @dest = msg[:dest]
        # find cloest node to our current pos
        @curr = closest_node @pos, @map
        @goal = closest_node @dest, @map
        
      when :update
        # do stuff
      end
    end
  end
end
