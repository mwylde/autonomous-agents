module Driving
  class App < Processing::App
    def setup
      @map = Map.from_file("#{File.dirname(__FILE__)}/../../maps/map.yaml")
      w = 800
      h = 600
      @display = Display.new(@map, w, h)
      size w, h
      frame_rate 30
      @display.setup
    end

    def draw
      @display.draw
    end
  end
end
