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
    MAX_DISPLAY_CRUMBS = 1000
    
    WORLD_DOT_RADIUS = 0.6
    POINT_RADIUS = 1
    INIT_ZOOM = 2300.0
    MIN_ZOOM = 5
    MAX_ZOOM = 1000000
    SLEEP_DURATION = 0.05
    attr_accessor :map, :g, :agents
    attr_reader :paused
    
    def initialize map, agents, w, h, camera_pos = nil
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

      puts @map.world_max
      puts @map.world_min
      default_pos = @map.world_max.midpt @map.world_min
      @c_pos = camera_pos || default_pos
       
      @display_crumbs = []
      @hidden_crumbs = []

      @input = InputHandler.new @c_pos.clone, INIT_ZOOM, MIN_ZOOM, MAX_ZOOM, self
      @paused = false
      addMouseMotionListener @input
      addMouseListener @input
      addMouseWheelListener @input
      addKeyListener @input
    end

    def paused= p
      puts "Setting paused to #{p}"
      @paused = p
      @agents.each{|a| a.paused = p}
    end

    def center a
      @c_pos = a.pos.clone
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

      if @input.following && @agents.size > 0
        a = @agents[@input.follow_agent % @agents.size]
        @c_pos = a.pos.clone
        @input.c_pos = @c_pos.clone
      else
        @c_pos = @input.c_pos.clone
      end

      if @paused
        @g.setColor(Color.red)
        @g.fillRect(0,0,20,20)
      end

      @z_y = @input.zoom

      # @hidden_crumbs = @agents.collect { |a| a.crumbs.collect { |c| c.clone }}.flatten
      
      render_map
      # render_crumbs :both
      render_agents

      @g.dispose

      @strategy.show
    end

    def render_map
      @map.road_set.each do |r|
        @g.set_color Color.red
        line r if on_screen? r
        r.walls.each do |w|
          @g.set_color Color.black
          line w if on_screen? w
        end
      end
    end

    def render_crumbs spec
      if spec == :both || spec == :hidden
        @g.set_color Color.blue
        @hidden_crumbs.each do |c|
          dot c if on_screen? c
        end
      end
      
      if spec == :both || spec == :display
        @g.set_color Color.green
        @display_crumbs.each do |c|
          dot c if on_screen? c
        end
      end
    end

    def render_agents
      @agents.each do |a|
        #if @display_crumbs.size >= MAX_DISPLAY_CRUMBS * @current_agents.size
        #  @display_crumbs.pop
        #end

        # @display_crumbs.unshift a.pos
        if a.dest
          @g.set_color Color.green
          dot a.dest
        end

        if a.renders
          a.renders.each{|x|
            eval x
          }
        end

        next unless on_screen? a.ne or on_screen? a.ne or on_screen? a.sw or
          on_screen? a.se
        
        @g.set_color Color.red
        polygon [a.ne, a.nw, a.sw, a.se], fill=true
        @g.set_color Color.black
        polygon [a.ne, a.nw, a.sw, a.se]
        
        polygon a.nw_tire_pts, fill=true
        polygon a.ne_tire_pts, fill=true
        polygon a.se_tire_pts, fill=true
        polygon a.sw_tire_pts, fill=true

        dot a.north

      end
    end

    # draws a very small circle of radius DOT_RADIUS centered at p in world
    # coordinates.
    def dot p
      circle p, WORLD_DOT_RADIUS
      # r = Vector.new(WORLD_DOT_RADIUS, WORLD_DOT_RADIUS)
      # s = p - r
      # v = r * 2

      # ellipse s, v
    end

    def point p
      p = world_to_screen p
      r = POINT_RADIUS
      @g.fill_oval p.x-r/2, p.y-r/2, r, r
    end

    # draws a line between two points specified in world coordinates.
    def line *args
      case args[0]
      when Driving::Point
        s_p0 = world_to_screen p0
        s_p1 = world_to_screen p1
      when Driving::LineSegment
        s_p0 = world_to_screen(args[0].p0)
        s_p1 = world_to_screen(args[0].p1)
      when Driving::Road
        s_p0 = world_to_screen(args[0].n0.pos)
        s_p1 = world_to_screen(args[0].n1.pos)
      else
        raise "Invalid specification of line to draw"
      end
      
      @g.draw_line s_p0.x, s_p0.y, s_p1.x, s_p1.y
    end

    # draws a circle of radius r at point c, both in world coordinates.
    def circle c, r
      vect = Vector.new(r,r)

      ellipse(c - vect, vect * 2)
    end
    
    # draws an ellipse starting at point p and with width/height described by
    # the vector v, in world coordinates.
    def ellipse p, v
      # fill_oval can only take positive displacements, so this draws the
      # specified ellipse in the right order to accomodate this.
      if v.x > 0
        if v.y > 0
          w_start = p + Vector.new(0, v.y)
          w_vect = Vector.new(v.x, -v.y)
        else
          w_start = p
          w_vect = vn
        end
      else
        if v.y > 0
          w_start = p + v
          w_vect = Vector.new(-v.x, -v.y)
        else
          w_start = p + Vector.new(v.x, 0)
          w_vect = Vector.new(-v.x, v.y)
        end
      end

      s_start = world_to_screen w_start
      s_end = world_to_screen w_start + w_vect
      s_vect = s_end - s_start

      @g.fill_oval s_start.x, s_start.y, s_vect.x, s_vect.y
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

    # valid inputs are: points, linesegments (and roads/walls), and items that
    # have a pos variable.
    def on_screen? p
      case p
      when Driving::Point
      when Driving::LineSegment
        # FIXME this should be smarter; right now the line only renders if its
        # end points or midpoint are on the screen, so this causes some funky
        # behavior. 
        return on_screen?(p.p0) || on_screen?(p.p1) ||
          on_screen?(p.p0.midpt(p.p1))
      when Driving::Road
        # FIXME: This should be smarter; right now the road only renders if its
        # end points or midpoints are on the screen, so this causes some funky
        # behavior.
        return on_screen?(p.n0) || on_screen?(p.n1) ||
          on_screen?(p.n0.pos.midpt(p.n1.pos))
      else
        return on_screen? p.pos
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

    attr_accessor :c_pos, :following, :follow_agent, :zoom, :zoom_min, :zoom_max
    def initialize c_pos, zoom, zoom_min, zoom_max, display
      @display = display
      @c_pos = c_pos
      @zoom = zoom
      @zoom_min = zoom_min
      @zoom_max = zoom_max
      @following = false
      @follow_agent = 0
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
      newz = @zoom * 0.75**(-increment)
      @zoom = newz if (newz < @zoom_max && newz > @zoom_min)
    end

    def keyPressed e
      case e.getKeyCode
      when KeyEvent::VK_SPACE then @following = !@following
      when KeyEvent::VK_LEFT then @follow_agent -= 1 if @following
      when KeyEvent::VK_RIGHT then @follow_agent += 1 if @following
      end

      case e.getKeyChar
      when 112 then @display.paused = !@display.paused # p
      end
    end

    def keyReleased e; end;
    def keyTyped e; end;
  end
end
