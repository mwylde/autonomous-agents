module Driving
  class App
    def setup
      @map = Map.from_file("#{File.dirname(__FILE__)}/../../maps/map.yaml")

      x, y = @map.latlong_to_world(37.5716897, -122.0797629)
      @agents = [Agent.new(0.01, 0.01, x, y)]
        
      @display = Display.new @map, @agents
      @display.draw
    end
  end
end
