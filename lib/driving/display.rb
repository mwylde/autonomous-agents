module Driving
  class Display
    def initialize map, p
      @map = map

      # the point at the world coordinates given by @camera_pos will be centered
      # on the screen.
      @camera_pos = map.world_max.collect {|x| x / 2}

      # @camera_zoom specifies the distance between the center of the camera and
      # the edge of the top or bottom screen boundaries (in world coordinates).
      @camera_zoom = 1

      # store reference to processing to access processing commands.
      @p = p
    end

    def aspect_ratio
      width() / height()
    end  

    def world_to_screen(x, y)
      a = [x, y]

      a[0] = x - @camera_pos[0] - aspect_ratio() * @camera_zoom
      a[1] = @camera_pos[0] + @camera_zoom - y

      return a
    end

    def on_screen?(x,y)
      sx, sy = world_to_screen x,y
      sx > 0 and sx < width() and sy > 0 and sy < height()
    end

    # draw point specified in world coordinates (only actually draws it if it's
    # on the screen).
    def point(x, y)
      if on_screen? x,y then
        sx,sy = world_to_screen x,y
        @p.point sx,sy
      end 
    end

    def width
      @p.width
    end

    def height
      @p.height
    end

    def setup
    end

    def draw
      @map.nodes.each do |n|
        point n.x, n.y
      end
    end
  end
end

