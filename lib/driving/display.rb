module Driving
  class Display
    attr_accessor :map
    
    def initialize map, p
      @map = map

      # the point at the world coordinates given by (@c_x, @c_y) will
      # be centered on the screen.
      @c_x = map.world_max[0] / 2.0
      @c_y = map.world_max[1] / 2.0

      # @z_yspecifies the distance between the center of the camera and the
      # edge of the top or bottom screen boundaries (in world coordinates).
      @z_y = 10

      # store reference to processing to access processing commands.
      @p = p
    end

    def aspect_ratio
      width() / height()
    end

    def zoom_x
      @z_y * aspect_ratio()
    end

    def zoom_y
      @z_y
    end
      

    def world_to_screen(x, y)
      sx = (x - (@c_x - zoom_x())) * ( width() / (2 * zoom_x()))
      sy = ((@c_y + zoom_y()) - y) * ( height() / (2 * zoom_y()))
      [sx, sy]
    end

    def on_screen?(x,y)
      x > @c_x - zoom_x() and x < @c_x + zoom_x() and
      y > @c_y - zoom_y() and y < @c_y + zoom_y()
    end

    # draw point specified in world coordinates (only actually draws it if it's
    # on the screen).
    def point(x, y)
      sx,sy = world_to_screen x,y
      @p.point sx,sy
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
        point n.x, n.y if on_screen? n.x, n.y
      end
    end
    
  end
  
end

