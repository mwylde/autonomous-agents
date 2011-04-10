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
    ROAD_WIDTH = 0.10
    WIDTH = 800
    HEIGHT = 600
    DOT_RADIUS = 3
    INIT_ZOOM = 10
    MIN_ZOOM = 1
    MAX_ZOOM = 30
    SLEEP_DURATION = 0.05
    attr_accessor :map
    
    def initialize map, agents
      puts "Creating display"
      
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

      puts "Running setup"
      @container.pack
      @container.setResizable false
      @container.setVisible true
      requestFocus

      createBufferStrategy(2)
      @strategy = getBufferStrategy
      
      # the point at the world coordinates given by (@c_x, @c_y) will
      # be centered on the screen.
      @c_pos = Point.new(map.world_max[0]/2.0, map.world_max[1]/2.0)
      @z_y = INIT_ZOOM

      # Get scroll wheel events
      @wheel = WheelListener.new @z_y, MIN_ZOOM, MAX_ZOOM
      @mouse = MouseDragger.new @c_pos, self
      addMouseMotionListener @mouse
      addMouseListener @mouse
      add_mouse_wheel_listener @wheel
    end

    def run
      while true
        
        @g = @strategy.getDrawGraphics
        @g.setRenderingHint RenderingHints::KEY_ANTIALIASING,
          RenderingHints::VALUE_ANTIALIAS_ON
        @g.setColor(Color.white)
        @g.fillRect(0,0,getWidth,getHeight)

        render_map

        @g.dispose
        @c_pos = @mouse.c_pos
        @z_y = @wheel.zoom

        @strategy.show
      end
    end

    def render_map
      @map.nodes.each do |n|
        n.neighbors.each do |m|
          # we don't want to draw stuff twice
          next if m.object_id > n.object_id
          if on_screen? n or on_screen? m
            road n.pos, m.pos
          end
        end
      end

      @g.setColor(Color.red)
      @agents.each do |a|
        ellipse a.pos, Vector.new(50,50) if on_screen? a
      end
    end

    # draws a road with lines connecting points p0 and p1), specified in world
    # coordinates
    def road p0, p1
      d = p0.dist p1

      # unit vector pointing from p0 to p1
      u = (p1.subtract_point p0).normalize!
      n = u.normal_vector
      n_road = n.scale ROAD_WIDTH
      n_road_neg = n.scale -ROAD_WIDTH
      
      a = p0.add_vector n_road
      b = p0.add_vector n_road_neg 
      c = p1.add_vector n_road
      d = p1.add_vector n_road_neg

      @g.setColor Color.black
      line a, c
      line b, d

      @g.setColor Color.red
      line p0, p1
    end

    # draws a very small circle of radius DOT_RADIUS centered at p in world
    # coordinates.
    def dot p
      r = DOT_RADIUS
      s_p = world_to_screen p
      
      ellipse(s_p.add_vector(Vector.new(-r, -r)), Vector.new(2*r, 2*r))
    end

    # draws a line between two points specified in world coordinates.
    def line p0, p1
      s_p0 = world_to_screen p0
      s_p1 = world_to_screen p1
      @g.draw_line s_p0.x, s_p0.y, s_p1.x, s_p1.y
    end

    # draws an ellipse starting at point p and with width/height described by
    # the vector v.
    def ellipse p, v
      x, y = p.x, p.y
      w, h = v.x, v.y
      @g.fill_oval x, y, w, h
    end

    #def polyline points
    #  xs, ys = points.fold [[],[]] do |acc, p|
    #    sX, sY = world_to_screen(*p)
    #    acc[0] << sX
    #    acc[1] << sY
    #  end
    #  @g.draw_polyline xs, ys, points.size
    #end

    #def polygon points
    #  xs, ys = points.fold [[],[]] do |acc, p|
    #    sX, sY = world_to_screen(*p)
    #    acc[0] << sX
    #    acc[1] << sY
    #  end
    #  @g.draw_polygon xs, ys, points.size
    #end
    
    # accessor methods for info which is dynamic (set by the window state or the
    # mouse state)
    
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
    
    def world_to_screen(p)
      wx = p.x
      wy = p.y
      
      sx = (wx - (@c_pos.x - zoom_x)) * ( getWidth / (2 * zoom_x))
      sy = ((@c_pos.y + zoom_y) - wy) * ( getWidth / (2 * zoom_x))
      
      Point.new(sx, sy)
    end

    def screen_to_world(p)
      sx = p.x
      sy = p.y
      
      wx = (2 * zoom_x * sx / getWidth) + (@c_pos.x - zoom_x)
      wy = (@c_pos.y + zoom_y) - (2 * zoom_y * sy / getWidth)
      
      Point.new(wx, wy)
    end

    # determines if a point in world coordinates is on the screen.
    def on_screen?(p)
      # allow on_screen? to be passed not only points, but objects which have a
      # point variable named pos
      if defined? p.pos
        p = p.pos
      end

      screen_p = world_to_screen p

      return (screen_p.x > 0 and screen_p.x < getWidth and
              screen_p.y > 0 and screen_p.y < getHeight)
    end

  end

  class MouseDragger
    include MouseListener
    include MouseMotionListener

    attr_accessor :c_pos
    def initialize c_pos, display
      @display = display
      @c_pos = c_pos
    end
    
    def mousePressed e
      @pmouse = Point.new(e.getX, e.getY)
    end

    def mouseDragged e
      p0 = @display.screen_to_world @pmouse
      p1 = @display.screen_to_world(Point.new(e.getX, e.getY))

      displacement = p0.subtract_point p1
      @c_pos.add_vector! displacement

      @pmouse = Point.new(e.getX, e.getY)
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
