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

    def to_s
      "Point (#{@x}, #{@y})"
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

    def to_s
      "Vector <#{@x}, #{@y}>"
    end

    def mag
      Math.sqrt(@x*@x + @y*@y)
    end

    def dir
      Math.tan(@y / @x)
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
      new_x = @x * Math.cos(theta) - @y * Math.sin(theta)
      new_y = @x * Math.sin(theta) + @y * Math.cos(theta)
      Vector.new(new_x, new_y)
    end
  end
end

   

    
        
        
