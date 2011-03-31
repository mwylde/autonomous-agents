module Driving
  class Display
    attr_accessor :map, :p
    
    def initialize map, agents, p
      @map = map
      @agents = agents
      # store reference to processing to access processing commands.
      @p = p
    end

    def setup
      @p.size 800, 600
      @p.frame_rate 60
      @p.smooth

      # the point at the world coordinates given by (@c_x, @c_y) will
      # be centered on the screen.
      @c_x = map.world_max[0] / 2.0
      @c_y = map.world_max[1] / 2.0

      # @z_yspecifies the distance between the center of the camera and the
      # edge of the top or bottom screen boundaries (in world coordinates).
      @z_y = 10.0
    end

    def draw
      render_map()
    end

    def render_map
      @p.background 255

      @p.color 0 # black
      @map.nodes.each do |n|
        point n.x, n.y if on_screen? n.x, n.y

        n.neighbors.each do |m|
          line n.x, n.y, m.x, m.y if on_screen? n.x, n.y or on_screen? m.x, m.y
        end
      end

      @p.color 255, 0, 0 # red
      @agents.each do |a|
        ellipse a.x, a.y, 1000, 1000 if on_screen? a.x, a.y
      end
    end

    # Processing event handlers. 
    # --------------------------------------------------------------------------
    # NOTE: these need to be assigned in app.rb to the REAL Processing sketch. -
    # --------------------------------------------------------------------------
    def mouse_clicked
      sx,sy = world_to_screen @c_x, @c_y
      @c_x, @c_y = screen_to_world sx, sy

      render_map()
    end
    
    def mouse_dragged
      wx0, wy0 = screen_to_world(@p.pmouse_x, @p.pmouse_y)
      wx1, wy1 = screen_to_world(@p.mouse_x, @p.mouse_y)

      @c_x -= wx1 - wx0
      @c_y -= wy1 - wy0

      render_map()
    end

    # wrapper methods for Processing which take world coordinates. -------------
    # --------------------------------------------------------------------------
    
    def point(x, y)
      sx,sy = world_to_screen x,y
      @p.point sx,sy
    end

    def line(x0, y0, x1, y1)
      sx0, sy0 = world_to_screen x0, y0
      sx1, sy1 = world_to_screen x1, y1
      @p.line sx0, sy0, sx1, sy1
    end

    def ellipse(x, y, w, h)
      sx, sy = world_to_screen x, y
      sw, sh = [w / zoom_x,  h / zoom_y]
      @p.ellipse sx, sy, sw, sh
    end
    
    # accessor methods for info which is gathered from Proessing. --------------
    # --------------------------------------------------------------------------

    def width
      @p.width
    end

    def height
      @p.height
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
      
    # coordinate manipulation. -------------------------------------------------
    # --------------------------------------------------------------------------
    
    def world_to_screen(wx, wy)
      sx = (wx - (@c_x - zoom_x())) * ( width() / (2 * zoom_x()))
      sy = ((@c_y + zoom_y()) - wy) * ( height() / (2 * zoom_y()))
      [sx, sy]
    end

    def screen_to_world(sx, sy)
      wx = (2 * zoom_x() * sx / width()) + (@c_x - zoom_x())
      wy = (@c_y + zoom_y()) - (2 * zoom_y() * sy / height())
      [wx, wy]
    end

    def on_screen?(x,y)
      x > @c_x - zoom_x() and x < @c_x + zoom_x() and
      y > @c_y - zoom_y() and y < @c_y + zoom_y()
    end

  end
  
end

