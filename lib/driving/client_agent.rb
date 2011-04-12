java_import java.net.Socket

module Driving
  class ClientAgent
    include Communicator

    def initialize host, port
      @port = port
      @host = host
      @socket = Socket.new @host, @port
      puts "Started #{self.class} on port #{@port}"
    end

    # Starts the agent read loop
    def run
      read
    end

    # Agent-specific handle_msg method. Every time the agent gets a
    # message from the server (which describes the current state of
    # the agent/environment) this method will be called. The agent
    # should respond by sending (using `send`) its current action (a
    # hash containing keys :delta_speed and :accel, containing the
    # agent's choice of those variables).
    def handle_msg msg
      throw Exception.new("Subclasses must override handle_msg")
    end
  end
end
