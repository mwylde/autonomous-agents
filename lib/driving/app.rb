module Driving
  class App < Processing::App
    load_ruby_library :yaml
    
    def setup
      @map = Map.from_file("#{File.dirname(__FILE__)}/../../maps/map.yaml")
      @display = Display.new(@map)
      size 800, 600
      frame_rate 30
      @display.setup
    end

    def draw
      @display.draw
    end
  end
end
