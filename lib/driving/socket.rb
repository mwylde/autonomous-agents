module Driving
  module Communicator
    # Sends a message on the socket.
    def send msg
      socket.send(YAML.dump(msg), 0)
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
      loop do
        # receive at most 8192 bytes, which is a mostly arbitrary
        # value that should work well
        chunk = socket.recv(8192)
        # a zero-length chunk means the connection was closed
        if chunk == ''
          socket.close
          puts "Lost connection, shutting down"
          exit
        end

        buffer += chunk
        # we use a single \x000 (i.e., null) as a messag eterminator,
        # so we look for one in the chunk. If there is one, then that
        # gives us a complete message and we can process it. If not,
        # we wait for more data on the socket.
        msg_end = buffer.index(0)
        while msg_end
          handle_msg(YAML.load(buffer[0..msg_end]))
          # get rid of teh stuff we've dealt with, plus the delimeter
          buffer = buffer[msg_end+1..-1]
          # and check to see if there's another message within the
          # buffer (which is unlikely, but not impossible)
          msg_end = buffer.index(0)
        end
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
