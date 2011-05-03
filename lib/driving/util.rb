module Driving
  class Point
    # Creates a new point with specified x, y coordinates
    def initialize x, y
      @x = x.to_f
      @y = y.to_f
    end

    # Point (0, 0)
    ZERO = self.new 0, 0

    attr_reader :x, :y

    # Creates point (x, y) from vector (x, y)
    def self.from_vector v
      Point.new v.x, v.y
    end

    # String representation of point
    def to_s p = 3
      "(%.#{p}f, %.#{p}f)" % [x, y]
    end

    # See `to_s`
    def inspect; to_s end

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

    # Finds the point along the specificed vector using this pooint as
    # the base
    def + v
      case v
      when Driving::Vector
        Point.new(@x + v.x, @y + v.y)
      else
        raise "Can only add a vector, not a #{v.class.name}, to a point"
      end

    end

    alias :add_vector :+

    # For vectors does `subtract_vector`. For pooints does `subtract_point`
    def -(a)
      case a
      when Driving::Vector then subtract_vector a
      when Driving::Point then subtract_point a
      else
        raise "Can only subtract a vector or a point, not a #{a.class}, from a point"
      end
    end

    # Calculates p-v
    def subtract_vector v
      Point.new(@x - v.x, @y - v.y)
    end

    # Finds vector between this point and the passed in point
    def subtract_point p
      Vector.new(@x - p.x, @y - p.y)
    end

    # Rotates the point around the vector from this point to p by theta
    def rotate_about p, theta
      v = self.-(p)
      p + v.rotate(theta)
    end

    # Euclidean distance between this point and p
    def dist p
      dx = p.x - @x
      dy = p.y - @y
      Math.sqrt(dx*dx + dy*dy)
    end

    # Find the midpoint between this point and point p.
    def midpt p
      self + (p - self)/2.0
    end

    # Converts to the array [x, y]
    def to_a
      [@x, @y]
    end

    def self.from_a a
      Point.new(a[0], a[1])
    end
  end

  # 2D vector class
  class Vector
    attr_reader :x, :y

    # Returns the vector (x, y) for point (x, y)
    def self.from_point p
      Vector.new p.x, p.y
    end

    # Computes a vector for the supplied magnitude and direction
    def self.from_mag_dir mag, dir
      Vector.new(mag * Math.cos(dir), mag * Math.sin(dir))
    end

    # Creates a unit vector with the specified angular direction
    def self.unit dir
      Vector.from_mag_dir 1, dir
    end

    # Creates the vector terminating at the specified (x, y) point
    def initialize x, y
      @x = x.to_f
      @y = y.to_f
    end

    # The zero vector (0, 0)
    ZERO = Vector.new 0, 0

    # String representation of the vector
    def to_s p = 3
      "<%.#{p}f, %.#{p}f>" % [@x, @y]
    end

    # Magnitude of the vector
    def mag
      return @mag || @mag = Math.sqrt(@x*@x + @y*@y)
    end

    # Direction of the vector in radians
    def dir
      Math.atan2(@y, @x)
    end

    # Direction of the vector in radians, normalized to be in the range [0,2pi]
    def dir_norm
      dir % (2*Math::PI)
    end

    # Returns true if this vector is unit (has magnitude 1), false
    # otherwise
    def unit?
      (mag - 1.0).abs < 0.001
    end

    # Returns a new vector with same direction and this one but unit
    # magnitude
    def normalize
      Vector.new(@x / mag, @y / mag)
    end

    # Computes the vector normal to this one
    def normal_vector
      Vector.new(@y, -@x)
    end

    # Takes a vector and adds it to this one
    def +(v)
      cname = v.class.name
      unless self.is_a? Driving::Vector
        raise "Can only add a vector, not a #{v}, to vector"
      end
      add_vector v
    end

    # Takes a vector and adds it to this one
    def add_vector v
      Vector.new(@x + v.x, @y + v.y)
    end

    # Subtracts a vector form this one
    def -(v)
      cname = v.class.name
      unless cname == "Driving::Vector"
        raise "Can only subtract a vector, not a #{cname}, from a vector"
      end
      subtract_vector v
    end

    # Takes a vector v and subtracts it from this one
    def subtract_vector v
      Vector.new(@x - v.x, @y - v.y)
    end

    # Scales the vector by the supplied constant
    def scale c
      Vector.new(c*@x, c*@y)
    end

    # See `scale`
    def *(c)
      case c
      when Fixnum, Float
        scale c
      else
        raise "Can only scale by a scalar, not a #{c.class.name}"
      end
    end

    # Scales by the inverse of the constant
    def /(c)
      self*(1/c)
    end

    # Rotates the vector by theta
    def rotate theta
      Vector.from_mag_dir(mag, dir + theta)
    end

    # Computes the dot product between this vector and v
    def dot v
      @x * v.x + @y * v.y
    end

    # Computes the angle between this vector and v
    def angle_from v
      dir - v.dir
    end
  end

  # A linesegment connects two points
  class LineSegment
    LARGE_NUMBER = 1000000
    
    attr_accessor :p0, :p1
    def initialize p0, p1
      @p0 = p0
      @p1 = p1
    end

    # Creates a "ray" based on a point and vector. This is essentially a line
    # segment starting at p heading in the direction of v for a very long
    # distance.
    def self.ray p, v
      LineSegment.new(p, p+v.normalize*LARGE_NUMBER)
    end

    # Creates a "line" based on a point and vector, or a previously created line
    # segment. This is essentially a line segment starting very far from p in
    # the negative v direction and heading very far along v.
    def self.line *args
      if args.length == 1
        if args[0].is_a? Driving::LineSegment
          l = args[0]
          LineSegment.new(l.p0-l.unit*LARGE_NUMBER,
                          l.p1+l.unit*LARGE_NUMBER)
        end
      else
        if args[0].is_a? Driving::Point and args[1].is_a? Driving::Vector
          p = args[0]
          v = args[1]
          LineSegment.new(p-v.normalize*LARGE_NUMBER,
                          p+v.normalize*LARGE_NUMBER)
        end
      end
    end

    def to_s
      "Segment #{@p0} -> #{@p1}"
    end

    def to_a
      [@p0.to_a, @p1.to_a]
    end

    def self.from_a a
      p0 = Point.from_a a[0]
      p1 = Point.from_a a[1]
      self.new p0, p1
    end
      
    # This computes the point which is closest to p on the line. The algorithm
    # is taken from http://paulbourke.net/geometry/pointline/
    def intersect_with_pt p
      x1 = @p0.x
      y1 = @p0.y
      x2 = @p1.x
      y2 = @p1.y
      x3 = p.x
      y3 = p.y

      if @p0.dist(@p1) == 0
        raise "Trying to intersect a point with a line that has no length"
      end
        
      u = ((x3-x1)*(x2-x1) + (y3-y1)*(y2-y1))/(@p0.dist @p1)**2
        
      x = x1 + u*(x2 - x1)
      y = y1 + u*(y2 - y1)

      Point.new x,y
    end

    # This returns the intersection point of two line segments, or nil if they
    # do not in fact intersect. Algorithm taken from
    # http://paulbourke.net/geometry/lineline2d/
    def intersection l
      e = 0.001
      x1, x2, x3, x4 = @p0.x, @p1.x, l.p0.x, l.p1.x
      y1, y2, y3, y4 = @p0.y, @p1.y, l.p0.y, l.p1.y
      denom  = (y4-y3) * (x2-x1) - (x4-x3) * (y2-y1)
      numera = (x4-x3) * (y1-y3) - (y4-y3) * (x1-x3)
      numerb = (x2-x1) * (y1-y3) - (y2-y1) * (x1-x3)

      # are the lines coincident?
      if numera.abs < e && numerb.abs < e && denom.abs < e
        return Point.new((x1 + x2)/2.0, (y1+y2)/2.0)
      end
      # are the lines parallel?
      return nil if denom.abs < e
      
      mua = numera/denom.to_f
      mub = numerb/denom.to_f
      return nil if mua < 0 || mua > 1 || mub < 0 || mub > 1
      return Point.new(x1 + mua * (x2 - x1), y1 + mua * (y2 - y1))
    end
    
    def dist_to_pt pt
      pt.dist(intersect_with_pt(pt))
      # x1 = @p0.x
      # x2 = @p1.x
      # y1 = @p0.y
      # y2 = @p1.y
      # 
      # a = (y2 - y1)/(x2 - x1)
      # b = 1.0
      # c = (y2-y1)/(x2-x1)*x1 - y1
      # 
      # (a*pt.x + b*pt.y + c).abs / Math.sqrt(a**2 + b**2)
    end

    def unit_from_pt pt
      intersect = intersect_with_pt pt
      (intersect - pt).normalize
    end

    def hits pt
      # FIXME: this is really primitive; this is really for the lien defined by
      # this line segment, not the line segment itself. need to do a check to
      # see if the point is actually on the extension of the segment.
      dist_to_pt(pt) < 0.01
    end

    # the unit vector pointing from p0 to p1
    def unit
      (@p1 - @p0).normalize
    end

    # a unit vector normal to the vector from p0 to p1
    def normal
      unit.normal
    end
  end
end
