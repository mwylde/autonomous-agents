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
    ROAD_WIDTH = 10
    WIDTH = 1400
    HEIGHT = 1000
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
      @wheel = WheelListener.new 10, 1, 30
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
      @map.nodes.each do |n|
        @g.setColor(Color.green)
        point n.x, n.y if on_screen? n.x, n.y

        #next unless rand < 0.5
        x1, y1 = world_to_screen n.x, n.y
        n.neighbors.each do |m|
          # we don't want to draw stuff twice
          next if m.object_id > n.object_id
          x2, y2 = world_to_screen m.x, m.y
          if on_screen? n.x, n.y or on_screen? m.x, m.y
            @g.setColor(Color.black)
            road x1, y1, x2, y2
            @g.setColor(Color.red)
            line n.x, n.y, m.x, m.y
          end
        end
      end

      @g.setColor(Color.red)
      @agents.each do |a|
        ellipse a.x, a.y, 50, 50 if on_screen? a.x, a.y
      end
    end
    
    # Draws a road with lanes
    def road x1, y1, x2, y2
      dx = (x2-x1).abs
      dy = (y2-y1).abs

      find_point = proc {|x, y, ax, ay|
        # magnitude of vector
        m = Math.sqrt(x*x+y*y)
        # scaling factor, so that magnitude becomes ROAD_WIDTH
        s = ROAD_WIDTH/m
        [x*s+ax, y*s+ay]
      }
      
      a = find_point.call(-dy, dx, x1, y1)
      b = find_point.call(dy, -dx, x1, y1)
      c = find_point.call(-dy, -dx, x2, y2)
      d = find_point.call(dy, dx, x2, y2)

      l1, l2 = a+d, b+c
      if dx < dy
        l1 = a+c
        l2 = b+d
      end

      @g.draw_line(*l1)
      @g.draw_line(*l2)
    end
    

    # wrapper methods for Processing which take world coordinates
    def point(x, y)
      sx,sy = world_to_screen x,y
      @g.fill_oval sx-5, sy-5, 10, 10
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
