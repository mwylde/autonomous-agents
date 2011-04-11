require 'optparse'

module Driving
  class App
    def initialize argv
      @options = {
        :map_file => "#{File.dirname(__FILE__)}/../../maps/map.yaml",
        :address => "127.0.0.1",
        :port => 8423,
        :w => 800,
        :h => 600
      }
      parser.parse! argv

      @map = Map.from_file(@options[:map_file])

      camera = @map.latlong_to_world(Point.new(37.5716897, -122.0797629))
      @agents = [ServerAgent.new 0, camera]
      
      @display = Display.new @map, @agents, @options[:w], @options[:h], camera

      @server = Server.new @options[:address], @options[:port]
    end

    def parser
      @parser ||= OptionParser.new do |opts|
        opts.banner = "Usage: driving [options]"
        opts.on("-m FILE", "--map FILE", "Location of YAML file containing the",
                "graph of the map") {|f|
          @options[:map_file] = f
        }
        opts.on("-a ADDRESS", "--address ADDRESS", "Bind address for server") {|a|
          @options[:address] = a
        }
        opts.on("-p PORT", "--port PORT", "Port to run server on") {|p|
          @options[:port] = p
        }
        opts.on("-g WxH", "--geometry WxH", "Window geometry (width by height)"){|s|
          @options[:w], @options[:h] = s.split("x").collect{|x| x.to_i}
        }
      end
    end
    
    def run
      Thread.abort_on_exception = true
      Thread.new do
        @server.run
      end
      # blocking
      @display.run
    end
  end
end
