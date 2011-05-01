module Driving
  if RUBY_ENGINE == 'jruby'
    java_import java.net.Socket
    class StandardSocket
      def initialize host, port
        @socket = Socket.new host, port
      end

      def self.from_socket socket
        s = self.allocate
        s.instance_variable_set(:@socket, socket)
        s
      end

      def method_missing name, *args
        @socket.send(name, *args)
      end
      
      def get_chunk
        @socket.get_input_stream.read() rescue nil
      end

      def send_msg str
        @socket.get_output_stream.write(str.to_java_bytes) rescue nil
      end
    end
  else
    require 'socket'
    class StandardSocket < Socket
      def initialize host, port
        super :INET, :STREAM
        sockaddr = Socket.pack_sockaddr_in(port, host)
        connect(sockaddr)
      end

      def get_chunk
        self.recv(1).bytes.first
      end

      def send_msg str
        write str
      end

      def close
      end
    end
  end
  
  module Communicator
    # Sends a message on the socket.
    def send msg
      str = YAML.dump(msg) + "\x0"
      socket.send_msg str
    end

    # Message read loop (blocking call) which waits for messages on
    # the socket and passes complete ones to `handle_msg`
    def read
      # Buffer for holding the received data. With sockets there is no
      # guarantee that you will receive the full message in a single
      # call to recv(). Accordingly, you have to have a buffer that
      # holds the partial data which is appended to on every recv
      # until you have a full message.
      buffer = ''
      #reader = BufferedReader.new(InputStreamReader.new(socket.get_input_stream))
      loop do
        # receive at most 8192 bytes, which is a mostly arbitrary
        # value that should work well
        chunk = socket.get_chunk
        # a zero-length chunk means the connection was closed
        if chunk == nil || chunk == '' || chunk == -1
          puts "Lost connection"
          @socket.close
          close
          break
        end

        # we use a single \x000 (i.e., null) as a messag eterminator,
        # so we look for one in the chunk. If there is one, then that
        # gives us a complete message and we can process it. If not,
        # we wait for more data on the socket.
        if chunk == 0
          begin
            msg = YAML.load(buffer)
          rescue ArgumentError
            msg = nil
            puts "Bad YAML recieved by #{self.class}"
          end
          handle_msg(msg) if msg
          buffer = ''
        else
          begin
            buffer << chunk
          rescue
            puts $!
          end
        end
      end

      # Called when the socket connection is lost.
      def close
      end

      # Returns the socket object to be used in other operations. Must
      # be implemented by modules that include Communicator.
      def socket
        throw Exception("socket must be implemented")
      end

      # Handles a message that's been received. Must be implemented by
      # moduels that include Communicator.
      def handle_msg msg
        throw Exception("handle_msg must be implemented")
      end
    end
  end
end
