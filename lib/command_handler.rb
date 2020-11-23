# This class contains the necessary functions to process user input
# It is intended to be a support class for the server itself

class CommandHandler

    # Commands supported by the server
    COMMANDS = [
        # Retrieval commands
        "get",
        "gets",

        # Storage commands
        "set",
        "add",
        "replace",
        "append",
        "prepend",
        "cas"
    ]

    def initialize(data, data_expiration)
        @logger = Logger.new(STDOUT)
        @logger.level = LOG_LEVEL
        @data = data
        @data_expiration = data_expiration
        @current_cas_value = 1
        # For testing purposes
        # @number_of_gets = 0
    end

    # Function definitions
    public

    # Identify which command is being called
    def get_command(arguments)
        # Split the input into the corresponding arguments
        command_parts = arguments.split
        # First argument is the intended Memcached command
        command = command_parts[0]

        # return the command
        command

    end

    # Check if a command is supported
    def is_command_supported(argument)
        if COMMANDS.include?(argument)
            true
        else
            false
        end
    end

    # handle single line commands (for instance, get)
    def handle_single_line(arguments)

        # first argument corresponds to the command
        command = arguments[0]
        # Args then stores the rest of the arguments
        args = arguments[1..-1]

        case command
        when "get"
            get(args, false)
        when "gets"
            get(args, true)
        else
            "ERROR"
        end

    end

    # Validate if the arguments follow the correct structure
    # Returns true if the command's arguments aren't breaking any rules
    def validate_command_arguments(command_parts, is_cas)
        response = true

        # The "cas" command follows a different structure
        # It will always ask for either 6 or 7 arguments
        # 0.command, 1.keyname, 2.flags, 3.time to live, 4.value length, 5.cas id, 6.optional noreply statement
        if is_cas
            if command_parts[1].length > 250 || command_parts[2].length > 5 || command_parts[3].length > 5 || command_parts[4].length > 2 || command_parts[5].length > 5
                response = false
            elsif !represents_positive_integer?(command_parts[2]) || !represents_integer?(command_parts[3]) || !represents_pos_integer?(command_parts[4]) || !represents_pos_integer?(command_parts[5])
                response = false
            end
        # The rest of the storage commands will always need to have either 5 or 6 arguments
        # 0.command, 1.keyname, 2.flags, 3.time to live, 4.value length, 5. optional noreply statement
        else
            if command_parts[1].length > 250 || command_parts[2].length > 5 || command_parts[3].length > 5 || command_parts[4].length > 2
                response = false
            elsif !represents_positive_integer?(command_parts[2]) || !represents_integer?(command_parts[3]) || !represents_pos_integer?(command_parts[4])
                response = false
            end
        end

        response

    end

    # true if there are 5 or 6 parts in the command, because that's the correct number of arguments for a command line
    def validate_command_number_of_arguments(command_parts, is_cas)
        response = true

        if is_cas
            if command_parts.length() != 6 && command_parts.length() != 7
                response = false
            end
        elsif command_parts.length() != 5 && command_parts.length() != 6
            response = false
        end

        response
    end

    # Helper function to check if a string represents a positive integer
    # Returns true if the argument string does represent a positive integer
    # Unlike the other two subsequent functions, this one will only recongnize positive integers with the format "x"
    # "+" or "-" before the number will not make it valid
    def represents_positive_integer?(string_to_check)
        is_positive_integer = false

        if string_to_check =~ /\A\d+\z/ ? true : false
            is_positive_integer = true
        end
        is_positive_integer

    end
    # To account for numbers starting with "+" or "-" (ie. +10, -10, etc)
    def represents_integer?(string_to_check)
        is_integer = false

        if string_to_check.length > 1
            rest_of_string = string_to_check[1..-1]
            if string_to_check.start_with?("+", "-")
                if rest_of_string =~ /\A\d+\z/ ? true : false
                    is_integer = true
                end
            else
                if string_to_check =~ /\A\d+\z/ ? true : false
                    is_integer = true
                end
            end
        else
            if string_to_check =~ /\A\d+\z/ ? true : false
                is_integer = true
            end
        end

        is_integer

    end
    # To account for numbers starting with only"+" (ie. +10)
    def represents_pos_integer?(string_to_check)
        is_integer = false

        if string_to_check.length > 1
            rest_of_string = string_to_check[1..-1]
            if string_to_check.start_with?("+")
                if rest_of_string =~ /\A\d+\z/ ? true : false
                    is_integer = true
                end
            else
                if string_to_check =~ /\A\d+\z/ ? true : false
                    is_integer = true
                end
            end
        else
            if string_to_check =~ /\A\d+\z/ ? true : false
                is_integer = true
            end
        end

        is_integer

    end

    # handle double line commands (for instance, set)
    def handle_double_line(command_line, datablock)
        # Split the command line into the corresponding arguments
        command_parts = command_line.split
        # First argument is the intended Memcached command
        command = command_parts[0]

        # key_name represents the key element of the key:value pair
        key_name = command_parts[1]
        # The "value_to_treat" array represents the value element of the key:value pair
        flags = command_parts[2]
        time_to_live = command_parts[3]
        datablock_length = command_parts[4]
        argument_cas = command_parts[5]
        cas_value = @current_cas_value.to_s
        # Remove the last 2 characters, because the value comes with an attached ""
        entry_value = datablock
        value_to_treat = [flags, datablock_length, cas_value, entry_value]

        expiration_time = ''
        if time_to_live.to_i.negative?()
            expiration_time = Time.now
        else
            expiration_time = Time.now + time_to_live.to_i
        end

        add_expiration = true
        if time_to_live.to_i == 0
            add_expiration = false
        end

        case command
        when "set"
            set(key_name, value_to_treat, add_expiration, expiration_time)
        when "add"
            add(key_name, value_to_treat, add_expiration, expiration_time)
        when "replace"
            replace(key_name, value_to_treat, add_expiration, expiration_time)
        when "append"
            append_prepend(key_name, value_to_treat, add_expiration, expiration_time, command)
        when "prepend"
            append_prepend(key_name, value_to_treat, add_expiration, expiration_time, command)
        when "cas"
            cass(key_name, value_to_treat, add_expiration, expiration_time, argument_cas)
        # Inform if the command is not supported
        else
            "ERROR"
        end

    end


    # RETRIEVAL COMMANDS ------------------------------------------------------------------------------
    def get(argument, is_gets)
        #For testint purposes
        #@number_of_gets += 1
        #puts @number_of_gets

        response = ""

        if !is_gets
            argument.each do |arg|
                if @data.has_key?(arg)
                    datablock = @data[arg][3].dup[0, @data[arg][1].to_i]
    
                    buffer = ""
                    buffer << "VALUE" << " " << arg << " " << @data[arg][0] << " " << @data[arg][1] << "\n" << datablock << "\n"
                    response << buffer
    
                end
            end
        else
            argument.each do |arg|
                if @data.has_key?(arg)
                    datablock = @data[arg][3].dup[0, @data[arg][1].to_i]
    
                    buffer = ""
                    buffer << "VALUE" << " " << arg << " " << @data[arg][0] << " " << @data[arg][1] << " " << @data[arg][2] << "\n" << datablock << "\n"
                    response << buffer
    
                end
            end
        end

        response << "END"
        response

    end

    # -------------------------------------------------------------------------------------------------

    # STORAGE COMMANDS --------------------------------------------------------------------------------
    # syntax: command key_name flags time_to_live datablock_length {cas id, if command is cas} optional_noreply
    def set(key_name, value_to_treat, add_expiration, expiration_time)

        if add_expiration
            @data_expiration[key_name] = expiration_time
        end

        @data[key_name] = value_to_treat
        # puts "datos guardados: flags length cas datablock"
        # puts @data[key_name]
        @current_cas_value += 1

        response = "STORED"
        response

    end

    def add(key_name, value_to_treat, add_expiration, expiration_time)
        if @data.has_key?(key_name)
            response = "NOT STORED"
            response
        else
            self.set(key_name, value_to_treat, add_expiration, expiration_time)
        end

    end

    def replace(key_name, value_to_treat, add_expiration, expiration_time)
        if @data.has_key?(key_name)
            self.set(key_name, value_to_treat, add_expiration, expiration_time)
        else
            response = "NOT STORED"
            response
        end
    end

    def append_prepend(key_name, value_to_treat, add_expiration, expiration_time, command)
        if @data.has_key?(key_name)

            original_length = @data[key_name][1].to_i
            argument_length = value_to_treat[1].to_i
            new_length = original_length + argument_length
            value_to_treat[1] = new_length.to_s

            new_value = @data[key_name][3].dup[0, original_length]
            value_to_append = value_to_treat[3].dup[0, argument_length]
            if command.eql? "append"
                new_value << value_to_append
                value_to_treat[3] = new_value
            elsif command.eql? "prepend"
                value_to_append << new_value
                value_to_treat[3] = value_to_append
            end

            # "The append and prepend commands do not accept flags or exptime. They update existing data portions, and ignore new flag and exptime settings."
            value_to_treat[0] = @data[key_name][0]
            self.set(key_name, value_to_treat, false, expiration_time)
        else
            response = "NOT STORED"
            response
        end
    end

    def cass(key_name, value_to_treat, add_expiration, expiration_time, argument_cas)
        if @data.has_key?(key_name)
            target_cas = @data[key_name][2]

            if target_cas.eql? argument_cas
                self.set(key_name, value_to_treat, add_expiration, expiration_time)
            else
                response = "EXISTS"
            end
        else
            response = "NOT FOUND"
            response
        end
    end
    # -------------------------------------------------------------------------------------------------

end