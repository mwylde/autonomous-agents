module Driving
  
  class Point
    attr_accessor :x, :y

    def self.from_vector v
      Point.new v.x, v.y
    end
    
    def initialize x, y
      @x = x.to_f
      @y = y.to_f
    end

    def inspect
      "Point (%.3f, %.3f)" % [x, y]
    end

    def to_s
      inspect
    end

    def add_vector v
      Point.new(@x + v.x, @y + v.y)
    end

    def add_vector! v
      @x += v.x
      @y += v.y
      self
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

    def rotate p, theta
      v = self.subtract_point p
      p.add_vector v.rotate(theta)
    end

    def dist p
      dx = p.x - @x
      dy = p.y - @y
      Math.sqrt(dx*dx + dy*dy)
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

    def inspect
      "Vector <%.3f, %.3f>" % [@x, @y]
    end

    def to_s
      inspect
    end

    def mag
      Math.sqrt(@x*@x + @y*@y)
    end

    def dir
      Math.atan(@y / @x)
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

    def subtract_vector! v
      @x -= v.x
      @y -= v.y
      self
    end

    def scale c
      Vector.new(c*@x, c*@y)
    end

    def rotate theta
      Vector.from_mag_dir(mag, dir + theta)
    end
  end
end

   

    
        
        
