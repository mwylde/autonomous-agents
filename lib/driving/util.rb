module Driving

  # Calculates the four points of the rectangle for the road segment
  # between p0 and p1
  def self.calculate_road p0, p1
    # unit vector pointing from p0 to p1
    n = (p1 - p0).normalize.normal_vector * ROAD_WIDTH
    
    a = p0 + n
    b = p0 - n
    c = p1 + n
    d = p1 - n
    [a, b, c, d]
  end
  
  class Point
    attr_accessor :x, :y

    def self.from_vector v
      Point.new v.x, v.y
    end
    
    def initialize x, y
      @x = x.to_f
      @y = y.to_f
    end

    ZERO = self.new 0, 0

    def to_s p = 3
      "Point (%.#{p}f, %.#{p}f)" % [x, y]
    end

    # Returns true if the point is in the convex polygon specified by
    # the four points a, b, c, d, false otherwise
    def in_convex_poly points
      c = false
      i = -1
      j = points.size - 1
      while (i += 1) < points.size
        if ((points[i].y <= self.y && self.y < points[j].y) || 
            (points[j].y <= self.y && self.y < points[i].y))
          if (self.x < (points[j].x - points[i].x) * (self.y - points[i].y) / 
              (points[j].y - points[i].y) + points[i].x)
            c = !c
          end
        end
        j = i
      end
      return c
    end

    def +(v)
      unless v.is_a? Driving::Vector
        raise "Can only add a vector, not a #{a.class}, to a point"
      end
      add_vector v
    end
    
    def add_vector v
      Point.new(@x + v.x, @y + v.y)
    end

    def add_vector! v
      @x += v.x
      @y += v.y
      self
    end

    def -(a)
      case a
      when Driving::Vector then subtract_vector a
      when Driving::Point then subtract_point a
      else
        raise "Can only subtract a vector or a point, not a #{a.class}, from a point"
      end
    end

    def subtract_vector v
      Point.new(@x - v.x, @y - v.y)
    end

    def subtract_vector! v
      @x -= v.x
      @y -= v.y
      self
    end

    def subtract_point p
      Vector.new(@x - p.x, @y - p.y)
    end

    def rotate_about p, theta
      v = self.-(p)
      p + v.rotate(theta)
    end

    def dist p
      dx = p.x - @x
      dy = p.y - @y
      Math.sqrt(dx*dx + dy*dy)
    end

    def midpt p
      self + (p - self)/2.0
    end

    def to_a
      [@x, @y]
    end
  end
  
  class Vector
    attr_accessor :x, :y

    def self.from_point p
      Vector.new p.x, p.y
    end

    def self.from_mag_dir mag, dir
      Vector.new(mag * Math.cos(dir), mag * Math.sin(dir))
    end
    
    def initialize x, y
      @x = x.to_f
      @y = y.to_f
    end

    ZERO = Vector.new 0, 0
    

    def to_s p = 3
      "Vector <%.#{p}f, %.#{p}f>" % [@x, @y]
    end

    def mag
      Math.sqrt(@x*@x + @y*@y)
    end

    def dir
      Math.atan2(@y, @x)
    end
    
    def unit?
      (mag - 1.0).abs < 0.001
    end

    def normalize
      Vector.new(@x / mag, @y / mag)
    end
    
    def normalize!
      unless unit?
        @x /= mag
        @y /= mag
      end
      self
    end

    def normal_vector
      Vector.new(@y, -@x)
    end

    def +(v)
      cname = v.class.name
      unless cname == "Driving::Vector"
        raise "Can only add a vector, not a #{cname}, to vector"
      end
      add_vector v
    end
    
    def add_vector v
      Vector.new(@x + v.x, @y + v.y)
    end

    def add_vector! v
      @x += v.x
      @y += v.y
      self
    end

    def subtract_vector v
      Vector.new(@x - v.x, @y - v.y)
    end

    def -(v)
      cname = v.class.name
      unless cname == "Driving::Vector"
        raise "Can only subtract a vector, not a #{cname}, from a vector"
      end
      subtract_vector v
    end

    def subtract_vector! v
      @x -= v.x
      @y -= v.y
      self
    end

    def scale c
      Vector.new(c*@x, c*@y)
    end

    def *(c)
      cname = c.class.name
      unless cname == "Fixnum" or cname == "Float"
        raise "Can only scale by a scalar, not a #{cname}"
      end
      scale c
    end

    def /(c)
      self*(1/c)
    end

    def rotate theta
      Vector.from_mag_dir(mag, dir + theta)
    end

    def dot v
      @x * v.x + @y * v.y
    end
  end
end
