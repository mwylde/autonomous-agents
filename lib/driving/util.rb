module Driving
  
  class Point
    attr_accessor :x, :y

    def self.from_vector v
      Point.new v.x, v.y
    end
    
    def initialize x, y
      @x = x
      @y = y
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
    end

    def subtract_vector v
      add_vector(v.scale(-1.0))
    end

    def subtract_vector! v
      add_vector!(v.scale(-1.0))
    end

    def subtract_point p
      Vector.new(@x - p.x, @y - p.y)
    end

    def rotate p, theta
      v = self.subtract_point p
      new_v = v.rotate theta
      return p.add_vector new_v
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
      @x = x
      @y = y
    end

    def to_s
      "Vector <#{@x}, #{@y}>"
    end

    def magnitude
      Math.sqrt(@x*@x + @y*@y)
    end
    
    def unit?
      magnitude == 1
    end

    def normalize!
      unless unit?
        m = magnitude
        @x = @x / m
        @y = @y / m
        self
      end
    end

    def normal_vector
      Vector.new(@y, -@x)
    end

    def add_vector v
      Vector.new(@x + v.x, @y + v.y)
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

   

    
        
        
