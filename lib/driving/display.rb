module Driving
  class Display
    def initialize map
      @map = map

      # the point at the world coordinates given by @camera_pos will be centered
      # on the screen.
#      @camera_pos = map.world_max.collect {|x| x / 2}

      # @camera_zoom specifies the distance between the center of the camera and
      # the edge of the top or bottom screen boundaries (in world coordinates).
      @camera_zoom = 1
    end

    def aspect_ratio
      width / height
    end  
    
    def world_to_screen(x, y)
      a = [x, y]

      a[0] = x - @camera_pos[0] - @camera_zoom
      a[1] = y - @camera_pos[1] - aspect_ratio() * @camera_zoom

      return a
    end  

    def setup
    end

    def draw
    end
  end
end

