require 'optparse'

module Driving
  class App
    def initialize argv
      @options = {
        :map_file => "#{File.dirname(__FILE__)}/../../maps/map.yaml",
        :address => "127.0.0.1",
        :port => 8423,
        :w => 800,
        :h => 600,
        :server => true
      }
      parser.parse! argv
    end

    def run
      if @options[:test]
        run_test
      elsif @options[:agent]
        run_agent
      else
        run_server
      end
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
        opts.on("-s", "--server", "Start server and display") {
          @options[:server] = true
        }
        opts.on("-c CLASS", "--agent CLASS", "Starts an agent with the supplied class"){|c|
          @options[:agent] = c
        }
        opts.on("-t", "--test", "Runs a non-interactive test with the",
                "specified agent and positions") {
          @options[:test] = true
        }
        opts.on("-s XxY", "--start XxY", "Provide the starting position of the",
                "agent in world coordinates for your map"){|s|
          @options[:pos] = Point.new(s.split("x").collect{|x| x.to_f})
        }
        opts.on("-d XxY", "--dest XxY", "Provide the destination position of the",
                "agent in world coordinates for your map"){|s|
          @options[:dest] = Point.new(s.split("x").collect{|x| x.to_f})
        }
      end
    end
    
    def run_server
      root = File.expand_path(File.dirname(__FILE__))
      require "#{root}/display"
      require "#{root}/server"

      @map = Map.from_file(@options[:map_file])

      @agents = [] #ServerAgent.new(0, @map)]

      @display = Display.new @map, @agents, @options[:w], @options[:h]

      @server = Server.new @options[:address], @options[:port], @map, @agents

      Thread.abort_on_exception = true
      Thread.new do
        @server.run
      end

      # Thread.new do
      #   sleep 1
      #   AStarAgent.new(@options[:address], @options[:port]).run
      # end

      # blocking
      @display.run
    end

    def run_agent
      puts "Starting agent: #{@options[:agent].inspect}"
      # get the agent corresponding to the one supplied at the command
      # line 
      begin
        klass = Driving.const_get(@options[:agent])
        klass.new(@options[:address], @options[:port]).run
      rescue NameError
        puts "Agent class #{@options[:agent]} doesn't exist."
      end
    end

    def run_test
      root = File.expand_path(File.dirname(__FILE__))
      require "#{root}/driving/server"
      puts "Starting test with #{@options[:agent]}"
      @agents = []
      @server = Server.new @options[:address], @options[:port], @map, @agents
      Thread.abort_on_exception = true
      Thread.new do
        @server.run
      end
      sleep 1
      AStarAgent.new(@options[:address], @options[:port]).run
    end
  end
end
