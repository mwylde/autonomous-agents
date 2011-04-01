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
      @p.size 1000, 760
      @p.frame_rate 60
      @p.smooth

      # the point at the world coordinates given by (@c_x, @c_y) will
      # be centered on the screen.
      @c_x = map.world_max[0] / 2.0
      @c_y = map.world_max[1] / 2.0

      # Get scroll wheel events
      @wheel = WheelListener.new(10, 2, 25)
      @p.add_mouse_wheel_listener(@wheel)
    end

    def draw
      # @z_yspecifies the distance between the center of the camera and the
      # edge of the top or bottom screen boundaries (in world coordinates).
      @z_y = @wheel.zoom

      render_map()
    end

    def render_map
      @p.background 255

      @p.fill 0 # black
      @map.nodes.each do |n|
        #next unless rand < 0.5
        point n.x, n.y if on_screen? n.x, n.y

        n.neighbors.each do |m|
          line n.x, n.y, m.x, m.y if on_screen? n.x, n.y or on_screen? m.x, m.y
        end
      end

      @p.fill 255, 0, 0 # red
      @agents.each do |a|
        ellipse a.x, a.y, 0.01, 0.01 if on_screen? a.x, a.y
      end
    end

    # Processing event handlers. 
    # NOTE: these need to be assigned in app.rb to the REAL Processing
    # sketch.
    
    def mouse_clicked
    end
    
    def mouse_dragged
      wx0, wy0 = screen_to_world(@p.pmouse_x, @p.pmouse_y)
      wx1, wy1 = screen_to_world(@p.mouse_x, @p.mouse_y)

      @c_x -= wx1 - wx0
      @c_y -= wy1 - wy0
    end

    # wrapper methods for Processing which take world coordinates
    
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
      x0, y0 = world_to_screen x, y
      x1, y1 = world_to_screen x+w, y+h
      @p.ellipse x0, y0, x1-x0, y1-y0
    end
    
    # accessor methods for info which is gathered from Proessing

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
      
    # coordinate manipulation
    
    def world_to_screen(wx, wy)
      sx = (wx - (@c_x - zoom_x())) * ( width() / (2 * zoom_x()))
      sy = ((@c_y + zoom_y()) - wy) * ( width() / (2 * zoom_x()))
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
  class WheelListener
    include java.awt.event.MouseWheelListener
    
    attr_reader :zoom, :max, :min

    # zoom is the initial value (for say z_start)
    # limit range of zoom with max

    def initialize(zoom, min, max)
      @zoom = zoom
      @min = min
      @max = max
    end
    
    def mouse_wheel_moved(e)
      increment = e.get_wheel_rotation       # increment/decrement
      newz = @zoom + increment
      @zoom = newz if (newz < @max && newz > @min)
    end
  end  
end
