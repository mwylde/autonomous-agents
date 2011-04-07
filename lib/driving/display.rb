include_class 'java.awt.Canvas'
include_class 'java.awt.Color'
include_class 'java.awt.Dimension'
include_class 'java.awt.Graphics2D'
include_class 'java.awt.event.ActionListener'
include_class 'java.awt.event.MouseListener'
include_class 'java.awt.event.MouseMotionListener'
include_class 'java.awt.image.BufferStrategy'
include_class 'java.awt.RenderingHints'
include_class 'javax.swing.JFrame'
include_class 'javax.swing.JPanel'

module Driving
  class Display < Canvas
    ROAD_WIDTH = 5
    WIDTH = 800
    HEIGHT = 600
    attr_accessor :map
    
    def initialize map, agents
      super()
      @container = JFrame.new "Autonomous Driving"
      @container.setDefaultCloseOperation JFrame::EXIT_ON_CLOSE      

      panel = @container.getContentPane
      panel.setPreferredSize Dimension.new(WIDTH, HEIGHT)
      panel.setLayout(nil)

      setBounds 0, 0, WIDTH, HEIGHT
      panel.add self

      setIgnoreRepaint true

      @map = map
      @agents = agents
    end

    def setup
      puts "Running setup"
      @container.pack
      @container.setResizable false
      @container.setVisible true
      requestFocus

      createBufferStrategy(2)
      @strategy = getBufferStrategy
      
      # the point at the world coordinates given by (@c_x, @c_y) will
      # be centered on the screen.
      @c_x = map.world_max[0] / 2.0
      @c_y = map.world_max[1] / 2.0

      # Get scroll wheel events
      @wheel = WheelListener.new 10, 2, 25
      @mouse = MouseDragger.new @c_x, @c_y, self
      addMouseMotionListener @mouse
      addMouseListener @mouse
      add_mouse_wheel_listener @wheel
      draw
    end

    def draw
      while true
        @g = @strategy.getDrawGraphics
        @g.setRenderingHint RenderingHints::KEY_ANTIALIASING,
          RenderingHints::VALUE_ANTIALIAS_ON
        @g.setColor(Color.white)
        @g.fillRect(0,0,getWidth,getHeight)
        # @z_yspecifies the distance between the center of the camera and the
        # edge of the top or bottom screen boundaries (in world coordinates).
        @z_y = @wheel.zoom
        @c_x = @mouse.c_x
        @c_y = @mouse.c_y

        render_map

        @g.dispose
        @strategy.show
        sleep 0.05
      end
    end

    def render_map
      @g.setColor(Color.black)
      rw2 = ROAD_WIDTH**2
      @map.nodes.each do |n|
        #next unless rand < 0.5
        n.neighbors.each do |m|
          if on_screen? n.x, n.y or on_screen? m.x, m.y
            road n.x, n.y, m.x, m.y
          end
        end
      end

      @g.setColor(Color.red)
      @agents.each do |a|
        ellipse a.x, a.y, 50, 50 if on_screen? a.x, a.y
      end
    end
    

    # wrapper methods for Processing which take world coordinates
    def road x1, y1, x2, y2
      # find the slope of the line that goes through (x1, y1)
      # and (x2, y2)
      m = (y2-y1)/(x2-x1).to_f
      # find the intercept and slope of the line perpendicular
      # to the above
      mp = -1/m
      bp1 = y1 - mp * x1
      bp2 = y2 - mp * x2

      # find the point for the road line above and below
      y2_m_y1_s = (y2 - y1)**2
      rw2 = ROAD_WIDTH ** 2
      find_point = proc{|rw2, xi, b|
        x = Math.sqrt((rw2 - y2_m_y1_s).abs) + xi
        y = mp * x + b
        [x,y]
      }

      a = find_point.call(rw2,  x1, bp1)
      b = find_point.call(-rw2, x1, bp1)
      c = find_point.call(rw2,  y1, bp2)
      d = find_point.call(-rw2, y1, bp2)

      line(*(a + b))
      line(*(c + d))
    end
    
    def point(x, y)
      sx,sy = world_to_screen x,y
      @g.fill_oval sx-1, sy-1, 2, 2
    end

    def polyline points
      xs, ys = points.fold [[],[]] do |acc, p|
        sX, sY = world_to_screen(*p)
        acc[0] << sX
        acc[1] << sY
      end
      @g.draw_polyline xs, ys, points.size
    end

    def polygon points
      xs, ys = points.fold [[],[]] do |acc, p|
        sX, sY = world_to_screen(*p)
        acc[0] << sX
        acc[1] << sY
      end
      @g.draw_polygon xs, ys, points.size
    end

    def line(x0, y0, x1, y1)
      sx0, sy0 = world_to_screen x0, y0
      sx1, sy1 = world_to_screen x1, y1
      @g.draw_line sx0, sy0, sx1, sy1
    end

    def ellipse(x, y, w, h)
      x0, y0 = world_to_screen x, y
      w, h = w / zoom_x, h / zoom_y
      @g.fill_oval x0, y0, w, h
    end
    
    # accessor methods for info which is gathered from Proessing
    
    def aspect_ratio
      getWidth / getHeight
    end

    def zoom_x
      @z_y * aspect_ratio()
    end

    def zoom_y
      @z_y
    end
      
    # coordinate manipulation
    
    def world_to_screen(wx, wy)
      sx = (wx - (@c_x - zoom_x)) * ( getWidth / (2 * zoom_x))
      sy = ((@c_y + zoom_y()) - wy) * ( getWidth / (2 * zoom_x))
      [sx, sy]
    end

    def screen_to_world(sx, sy)
      wx = (2 * zoom_x * sx / getWidth) + (@c_x - zoom_x)
      wy = (@c_y + zoom_y) - (2 * zoom_y * sy / height)
      [wx, wy]
    end

    def on_screen?(x,y)
      x > @c_x - zoom_x and x < @c_x + zoom_x and
      y > @c_y - zoom_y and y < @c_y + zoom_y
    end

  end

  class MouseDragger
    include MouseListener
    include MouseMotionListener

    attr_accessor :c_x, :c_y
    def initialize c_x, c_y, display
      @display = display
      @c_x = c_x
      @c_y = c_y
    end
    
    def mousePressed e
      @pmouse = [e.getX, e.getY]
    end

    def mouseDragged e
      wx0, wy0 = @display.screen_to_world(*@pmouse)
      wx1, wy1 = @display.screen_to_world(e.getX, e.getY)

      @c_x -= wx1 - wx0
      @c_y -= wy1 - wy0
      @pmouse = e.getX, e.getY
    end
    
    def mouseReleased e
      @pmouse = nil
    end

    def mouseEntered e; end;
    def mouseClicked e; end;
    def mouseExited e; end;
    def mouseMoved e; end;
    def mouseWheelMoved e; end

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
