require 'socket'
require 'timeout'

class MemcachedClient
    # This is the time the client will wait after inputting someone to the server
    INPUT_LOCK = 0.02

    TERMINATION_MESSAGES = [
      "END",
      "ERROR",
      "STORED",
      "NOT STORED",
      "EXISTS",
      "NOT FOUND",
      "CLIENT_ERROR bad command line format"
    ]

    def initialize
        @socket = TCPSocket.new 'localhost', 2000
    end

    public

    def resolve_request(args)
        args.each do |arg|
            treated_arg = arg
            treated_arg << " "
            @socket.puts treated_arg
            sleep(INPUT_LOCK)
        end
        response = read_response()
        close_server()
        response
    end

    def read_response
        buffer = ""
        line = ""
        until TERMINATION_MESSAGES.include?(line.strip)
            line = @socket.gets
            buffer << line
        end
        buffer
    end

    def close_server
        @socket.close
    end
end

=begin
while line = socket.gets
            buffer << line << "\n"
            if SINGLE_LINE_COMMANDS.include?(line.strip)
                break
            end
        end
=end