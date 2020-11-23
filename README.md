# Memcached-Server-Ruby-ver-1.0.0
An implementation of a Memcached server, written in Ruby and supporting a subset of Memcached's commands, with tests covering each command and also a server performance (load) test

Installation
--------------
This implementation has been written and tested using Ruby 2.5.1p57

First, clone this repository:

    $ git clone "current_address"
    
Once within the root directory (may need sudo):

    /root$ bundle install
    
    
Features
--------------
The server stores a set of key:value pairs, making use of Ruby's hash implementation. Besides key and value data it also stores some addtitional information related to each pair:
* key_name: the name of the key, which is generally used to access and modify it.
* key_value: the datablock held by the key.
* flags: an integer value.
* time_to_live: a Time object representing the key's expiration date.
* value_length: an integer representing the length of the datablock held by the key.
* cas_id: a unique cas identifier, related to the usage of two of the supported commands.

For more information on each value, visit: https://github.com/memcached/memcached/blob/master/doc/protocol.txt.

The server supports a subset of Memcached's commands. Storage commands accept the following syntax:

    <command> <key_name> <flags> <time_to_live> <value_length> <noreply>
    cas <key_name> <flags> <time_to_live> <value_length> <cas_id> <noreply>
    
Retrieval commands accept the following the syntax:

    get <key>*\r\n
    gets <key>*\r\n
    
Any sort of mismatch between the number of arguments and the intended syntax will result in an "ERROR" response. This will also happen if the first argument does not coincide with any of the supported commands. The server supports the following commands:

*Storage:*
* [set](https://www.tutorialspoint.com/memcached/memcached_set_data.htm)
* [add](https://www.tutorialspoint.com/memcached/memcached_add_data.htm)
* [replace](https://www.tutorialspoint.com/memcached/memcached_replace_data.htm)
* [append](https://www.tutorialspoint.com/memcached/memcached_append_data.htm)
* [prepend](https://www.tutorialspoint.com/memcached/memcached_prepend_data.htm)
* [cas](https://www.tutorialspoint.com/memcached/memcached_cas.htm)

*Retrieval:*
* [get](https://www.tutorialspoint.com/memcached/memcached_get_data.htm)
* [gets](https://www.tutorialspoint.com/memcached/memcached_get_cas_data.htmm)

The server can manage multiple clients and features a persistent connection. Clients will not be forcefully disconnected unless the server stops running.

Running the Server
--------------
To run the server, open a terminal, go the *lib* directory and then type:

    /root/lib$ ruby main.rb
    
The server will start running on localhost, port 2000, and can be interacted with using the telnet command. Multiple clients can connect the server via telnet.

    $ telnet localhost 2000
    
To kill the server process, simply type CTRL+C in the console it's running on.

Running tests
--------------
The server ships with a pre-made set of unit tests, using the RSpec gem. To run these tests, on the root directory, type:

    /root$ bin/rspec --format doc
    
To check the test file, add more tests or knowing what's happening behind them, go to */root/spec/server_spec.rb*.
    
***IMPORTANT NOTICE***: the server must be restarted before executing these tests in order for all of them to run successfully. This is because some of the commands are sensitive to pre-existing values.

Running a performance test
--------------
On the *lib* directory, type:

    /root/lib$ ruby load_tests.rb
    
The parameters of this test can be customized in the */root/lib/load_tests.rb*.file, by changing The N_THREADS and CLIENTS constants. This test evaluates how does the server fare under multiple connection and command requests.
