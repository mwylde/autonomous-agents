require 'optparse'

module Driving
  class App
    def initialize argv
      @options = {
        :map_file => "#{File.dirname(__FILE__)}/../../maps/map.yaml",
        :port => 8423,
        :w => 800,
        :h => 600
      }
      parser.parse! argv
    end

    def parser
      @parser ||= OptionParser.new do |opts|
        opts.banner = "Usage: driving [options]"
        opts.on("-m FILE", "--map FILE", "Location of YAML file containing the",
                "graph of the map") {|f|
          @options[:map_file] = f
        }
        opts.on("-p PORT", "--port PORT", "Port to run server on") {|p|
          @options[:port] = p
        }
        opts.on("-g WxH", "--geometry WxH", "Window geometry (width by height)"){|s|
          @options[:w], @options[:h] = s.split("x").collect{|x| x.to_i}
        }
      end
    end
    
    def setup
      @map = Map.from_file(@options[:map_file])

      x, y = @map.latlong_to_world(37.5716897, -122.0797629)
      @agents = [Agent.new(0.01, 0.01, x, y)]
        
      @display = Display.new @map, @agents, @options[:w], @options[:h]
      @display.run
    end
  end
end
