java_import java.net.ServerSocket
java_import java.net.InetSocketAddress

module Driving
  class Server
    def initialize address, port, map, agents
      @address = address
      @port = port
      @map = map

      # a counter which lets us give unique ids to each agent
      @id_counter = 0
      
      # Create the socket with recommended options
      @socket = ServerSocket.new

      # This lets us reconnect to ports which haven't yet been released
      # by the OS. This is convenient for development because without
      # this you have to wait a minute or so in between each run of the
      # server to restart it.
      @socket.set_reuse_address true

      # array of agents currently in the simulation
      @agents = agents

      # Add handler for SIGINT, so we can clean up
      Signal.trap("TERM") { cleanup }
      Signal.trap("INT") { cleanup }
    end

    # Closes the socket and dies nicely
    def cleanup
      @socket.close
      puts "Got signal, dying"
      exit
    end

    # Starts the server on the specified port
    def run
      # bind to the correct address/port
      @socket.bind(InetSocketAddress.new(@address, @port))

      # Main server loop. Wait for connections and spawn off a thread
      # to handle each.
      loop do
        # blocking call that waits for connections
        client = @socket.accept
        puts "Agent connected"
        @agents << RemoteServerAgent.new(client, @id_counter, @map)
        # start the agent's non-blocking run loop
        @gents[-1].run
        @id_counter += 1
      end
    end
  end
end
