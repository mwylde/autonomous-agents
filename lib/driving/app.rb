module Driving
  class App < Processing::App
    def setup
      @map = Map.from_file("#{File.dirname(__FILE__)}/../../maps/map.yaml")
      @display = Display.new(@map, self)
      size 800, 600
      frame_rate 30
      @display.setup
    end

    def draw
      @display.draw
    end

    def mouse_clicked
      @display.mouse_clicked
    end

    def mouse_dragged
      @display.mouse_dragged
    end
  end
end
