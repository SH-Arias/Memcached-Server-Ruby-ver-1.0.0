require 'socket'
require 'timeout'
require 'logger'

# Replace LOG_LEVEL with the desired logging level
# For isntance: LOG_LEVEL = Logger::DEBUG
LOG_LEVEL = ENV['DEBUG'] ? Logger::DEBUG : Logger::INFO

require_relative 'expiration_checker'
require_relative 'command_handler'

class MemcachedServer

    SINGLE_LINE_COMMANDS = [
      "get",
      "gets"
    ]

    DOUBLE_LINE_COMMANDS = [
      "set",
      "add",
      "replace",
      "append",
      "prepend",
      "cas"
    ]
  
    # How many times is the expiration check allowed be executed per server_cron run
    MAX_EXPIRATION_CHECKS_PER_CYCLE = 20
    # How many times does server_cron run per second
    DEFAULT_CRON_FREQUENCY = 10
  
    # Struct to store a certain time event
    # The first argument marks the timestamp at which the event must be processed
    # The second argument represents the event which will be executed
    TimeEvent = Struct.new(:process_at, :block)

    # Struct to hold Clients.
    # Some commands execute only after the client presses enter a certain number of times (ie set),
    # so it is necessary to hold the socket input until after the command is actually processed
    Client = Struct.new(:socket, :command_buffer, :datablock_buffer, :ready, :max_datablock_length) do
      def initialize(socket)
        self.socket = socket
        self.command_buffer = ''
        self.datablock_buffer = ''
        self.ready = true
        self.max_datablock_length = 0
        #self.current_datablock_length
      end
    end
  
    # Server initialization
    def initialize

        # Logging tool
        @logger = Logger.new(STDOUT)
        @logger.level = LOG_LEVEL
  
        # Current clients connected to the server
        @clients = []
        # data is the hash which stores the key value pairs being cached by the server
        # data_expiration is the hash which stores the expiration times of said pairs
        @data = {}
        @data_expiration = {}

        # Command handler
        @handler = CommandHandler.new(@data, @data_expiration)

        # Start the Server and bind it to port 2000
        @server = TCPServer.new 2000
        # time_events stores scheduled events
        @time_events = []
        @logger.debug "Server started at: #{ Time.now }"
        # Add the server_cron event, set to execute @1ms in the future
        add_time_event(Time.now.to_f.truncate + 1) do
            server_cron
        end
  
        # Start the server's main loop
        start_event_loop
    end
  
    # Function definitions
    private
  
    # Add a certain time event to scheduled events
    def add_time_event(process_at, &block)
      @time_events << TimeEvent.new(process_at, block)
    end
  
    # Find and return the nearest scheduled event
    def nearest_time_event
      now = (Time.now.to_f * 1000).truncate
      nearest = nil
      @time_events.each do |time_event|
        if nearest.nil?
          nearest = time_event
        elsif time_event.process_at < nearest.process_at
          nearest = time_event
        else
          next
        end
      end
  
      nearest
    end
  
    # Defines how much time will the 'select' call wait for before returning nil
    # nil is returned if no object from the ones passed to select is ready to be read after the timeout
    # Since the server_cron executes every 100ms, timeout will be at most 100ms
    def select_timeout
      if @time_events.any?
        nearest = nearest_time_event
        now = (Time.now.to_f * 1000).truncate
        if nearest.process_at < now
          0
        else
          (nearest.process_at - now) / 1000.0
        end
      else
        0
      end
    end

    # Apply to_proc to the socket object
    def client_sockets
      @clients.map(&:socket)
    end
  
    # The server's main loop
    # The server tries to process client input with select
    # Nonetheless, it will also be ready to constantly execute other events,
    # such as checking for keys which are ready to be purged
    def start_event_loop
      loop do
        timeout = select_timeout
        @logger.debug "select with a timeout of #{ timeout }"
        result = IO.select(client_sockets + [@server], [], [], timeout)
        sockets = result ? result[0] : []
        process_poll_events(sockets)
        process_time_events
      end
    end
  
    # Read client input from sockets
    def process_poll_events(sockets)
      sockets.each do |socket|
        begin
          if socket.is_a?(TCPServer)
            @clients << Client.new(@server.accept)
          elsif socket.is_a?(TCPSocket)
            client = @clients.find { |client| client.socket == socket }
            client_command_with_args = socket.read_nonblock(256, exception: false)
            if client_command_with_args.nil?
              @clients.delete(client)
              socket.close
            elsif client_command_with_args == :wait_readable
              # There's still no client input, break iteration
              next
            elsif client_command_with_args.empty?
              @logger.debug "Empty request"
            # There's client input waiting to be treated with
            else
              # By default, client input is ready to be read
              if client.ready
                # First and foremost, client input has to start with a valid command
                command = @handler.get_command(client_command_with_args)
                command_line = client_command_with_args.split
                is_cas = command.eql? "cas"
                # Check if a supported command has been inputted
                if @handler.is_command_supported(command)
                  # The command is supported, but it can then be a single line command
                  if SINGLE_LINE_COMMANDS.include?(command)
                    if command_line.length < 2
                      socket.puts "ERROR"
                    else
                      response = @handler.handle_single_line(command_line)
                      socket.puts response
                    end

                  elsif !@handler.validate_command_number_of_arguments(command_line, is_cas)
                    socket.puts "ERROR"
                  # or it can also be a double line command (1st line is the command, 2nd line is the datablock)
                  else
                    # By now, only the 1st line has been inputted, and the server has to wait for the datablock
                    # So make sure the command line is a valid one,
                    # store the first it, and change the client's ready property
                    #command_line = client_command_with_args.split
                    if @handler.validate_command_arguments(command_line, is_cas)
                      client.command_buffer += client_command_with_args
                      client.max_datablock_length = command_line[4].to_i.abs
                      client.ready = false
                    else
                      socket.puts "CLIENT_ERROR bad command line format"
                    end
                    
                  end
                # Memcached's default response for a non supported command is "ERROR"
                else
                  socket.puts "ERROR"
                end
              # The ready property is set to false when the server is waiting for the datablock
              # Very important: a key value can hold endlines "("\n")" which will count as 2 characters
              else
                client.datablock_buffer += client_command_with_args
                # The actual datablock length is 2 units less, since \n (after pressing enter) does count
                comparative_helper = client.datablock_buffer.length - 2
                if comparative_helper > client.max_datablock_length
                  # Reset client data for the next iteration
                  client.max_datablock_length = 0
                  client.command_buffer = ''
                  client.datablock_buffer = ''
                  client.ready = true
                  response = ""
                  response << "CLIENT_ERROR bad data chunk" << "\n"
                  response << "ERROR"
                  socket.puts response

                elsif comparative_helper == client.max_datablock_length
                  response = @handler.handle_double_line(client.command_buffer, client.datablock_buffer)

                  # It is necessary to check is there's a valid "noreply" option active
                  command = @handler.get_command(client.command_buffer)
                  command_line = client.command_buffer.split
                  is_cas = command.eql? "cas"
                  noreply_active = false

                  # Reset client data for the next iteration
                  client.command_buffer = ''
                  client.datablock_buffer = ''
                  client.ready = true

                  # Validate correct noreply 
                  # Memcached only cares about the optional noreply if it is written correctly
                  # A wrong writing (ie anything not coinciding with "noreply") won't prevent the command from executing,
                  # But won't cause the execution to terminate badly either
                  if is_cas && command_line.length == 7
                    if command_line[6].eql? "noreply"
                      noreply_active = true
                    end
                  elsif command_line.length == 6
                    if command_line[5].eql? "noreply"
                      noreply_active = true
                    end
                  end

                  # Finally, provide a response if noreply is not active
                  if !noreply_active
                    socket.puts response
                  end

                end

              end

            end
          else
            raise "Unknown socket type: #{ socket }"
          end
        rescue Errno::ECONNRESET
          @clients.delete(socket)
        end
      end
    end
    
    # Process the scheduled time events
    # Time events are basically made up server_crons and selects to catch client input
    def process_time_events
      @time_events.delete_if do |time_event|
        next if time_event.process_at > Time.now.to_f * 1000
  
        return_value = time_event.block.call
  
        if return_value.nil?
          true
        else
          time_event.process_at = (Time.now.to_f * 1000).truncate + return_value
          @logger.debug "Rescheduling time event #{ Time.at(time_event.process_at / 1000.0).to_f }"
          false
        end
      end
    end

    # The server_cron is the utility which continuosly checks for expired keys in order to purge them
    # It will only check a certain number of keys per cycle, though, since the server needs to process other events
    def server_cron
      start_timestamp = Time.now
      keys_fetched = 0
  
      @data_expiration.each do |key, _|
        if @data_expiration[key] < Time.now
          @logger.debug "Evicting #{ key }"
          @data_expiration.delete(key)
          @data.delete(key)
          # purging_key_notice = "deleting key with name: "
          # purging_key_notice += key
          # puts purging_key_notice
        end
  
        keys_fetched += 1
        if keys_fetched >= MAX_EXPIRATION_CHECKS_PER_CYCLE
          break
        end
      end
  
      end_timestamp = Time.now
      @logger.debug do
        sprintf(
          "Processed %i keys in %.3f ms", keys_fetched, (end_timestamp - start_timestamp) * 1000)
      end
  
      1000 / DEFAULT_CRON_FREQUENCY
    end
  end