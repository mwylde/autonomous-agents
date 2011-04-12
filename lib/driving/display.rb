include_class 'java.awt.Canvas'
include_class 'java.awt.Color'
include_class 'java.awt.Dimension'
include_class 'java.awt.Graphics2D'
include_class 'java.awt.Polygon'
include_class 'java.awt.event.ActionListener'
include_class 'java.awt.event.MouseListener'
include_class 'java.awt.event.MouseMotionListener'
include_class 'java.awt.event.MouseWheelListener'
include_class 'java.awt.event.KeyListener'
include_class 'java.awt.event.KeyEvent'
include_class 'java.awt.image.BufferStrategy'
include_class 'java.awt.RenderingHints'
include_class 'javax.swing.JFrame'
include_class 'javax.swing.JPanel'

module Driving
  class Display < Canvas
    ROAD_WIDTH = 0.10
    DOT_RADIUS = 3
    INIT_ZOOM = 3
    MIN_ZOOM = 0.5
    MAX_ZOOM = 30
    SLEEP_DURATION = 0.05
    attr_accessor :map
    
    def initialize map, agents, w, h, camera_pos
      puts "Creating display"
      
      super()
      @container = JFrame.new "Autonomous Driving"
      @container.setDefaultCloseOperation JFrame::EXIT_ON_CLOSE      

      panel = @container.getContentPane
      panel.setPreferredSize Dimension.new(w, h)
      panel.setLayout(nil)

      setBounds 0, 0, w, h
      panel.add self

      setIgnoreRepaint true

      @map = map
      @agents = agents

      @container.pack
      @container.setResizable false
      @container.setVisible true
      requestFocus

      createBufferStrategy(2)
      @strategy = getBufferStrategy

      @c_pos = camera_pos
      # @c_pos = Point.new(map.world_max[0]/2.0, map.world_max[1]/2.0)

      @input = InputHandler.new @c_pos.clone, INIT_ZOOM, MIN_ZOOM, MAX_ZOOM, self
      addMouseMotionListener @input
      addMouseListener @input
      addMouseWheelListener @input
      addKeyListener @input
    end

    def run
      loop { draw }
    end

    def draw
      @g = @strategy.getDrawGraphics
      @g.setRenderingHint RenderingHints::KEY_ANTIALIASING,
      RenderingHints::VALUE_ANTIALIAS_ON
      @g.setColor(Color.white)
      @g.fillRect(0,0,getWidth,getHeight)

      if @input.following
        @c_pos = @agents[0].pos.clone
        @input.c_pos = @c_pos.clone
      else
        @c_pos = @input.c_pos.clone
      end
      
      @z_y = @input.zoom
      
      render_map
      render_agents

      @g.dispose

      @strategy.show
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
    end

    def render_agents
      @agents.each do |a|
        next unless on_screen? a.ne or on_screen? a.ne or on_screen? a.sw or
          on_screen? a.se
        @g.set_color Color.red
        polygon [a.ne, a.nw, a.sw, a.se], fill=true
        @g.set_color Color.black
        polygon [a.ne, a.nw, a.sw, a.se]
      end
    end

    # draws a road with lines connecting points p0 and p1), specified in world
    # coordinates
    def road p0, p1
      # unit vector pointing from p0 to p1
      n = (p1.subtract_point p0).normalize.normal_vector.scale ROAD_WIDTH
      
      a = p0.add_vector n
      b = p0.subtract_vector n
      c = p1.add_vector n
      d = p1.subtract_vector n

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
      p0 = world_to_screen(p)
      p1 = world_to_screen(p.add_vector v)
      v = p1.subtract_point p0

      @g.fill_oval p0.x, p0.y, v.x, v.y
    end

    def polyline points
      xs, ys = points.reduce [[],[]] do |acc, p|
        p = world_to_screen p
        acc[0] << p.x
        acc[1] << p.y
      end
      @g.draw_polyline xs, ys, points.size
    end

    def polygon points, fill=false
      xs, ys = points.reduce [[],[]] do |acc, p|
        p = world_to_screen p
        acc[0] << p.x
        acc[1] << p.y
        acc
      end

      xs = xs.to_java(Java::int)
      ys = ys.to_java(Java::int)
      p = points.size

      poly = Polygon.new(xs, ys, p)
      if fill
        @g.fill poly
      else
        @g.draw poly
      end
    end
    
    # accessor methods for info which is dynamic (set by the window state or the
    # mouse state)
    
    def aspect_ratio
      getWidth / getHeight
    end

    def zoom_x
      @z_y * aspect_ratio
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

  class InputHandler
    include KeyListener
    include MouseListener
    include MouseMotionListener
    include MouseWheelListener

    attr_accessor :c_pos, :following, :zoom, :zoom_min, :zoom_max
    def initialize c_pos, zoom, zoom_min, zoom_max, display
      @display = display
      @c_pos = c_pos
      @zoom = zoom
      @zoom_min = zoom_min
      @zoom_max = zoom_max
      @following = false
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

    def mouseWheelMoved e
      increment = e.get_wheel_rotation   # increment/decrement
      newz = @zoom + increment
      @zoom = newz if (newz < @zoom_max && newz > @zoom_min)
    end

    def keyPressed e
      if e.getKeyCode == KeyEvent::VK_SPACE
        @following = ! @following
      end
    end

    def keyReleased e; end;
    def keyTyped e; end;
  end
end
      

=begin 
  class KeybdListener
    include KeyListener

    attr_accessor :following
    def initialize following
      @following = following
    end

    def keyPressed e
      if e.get_key_text == "SPACE"
        @following != @following
      end
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
    include MouseWheelListener
    
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
=end
