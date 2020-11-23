require_relative 'memcached_client'

# Number of threads for the test
N_THREADS = 10
# Number of clients to be simulated
CLIENTS = 150

# Terminate the test if an exception is raised
Thread.abort_on_exception = true

# Save the threads. Each thread will simulate
threads = []

# Insert the key which will be asked to the server
target = MemcachedClient.new
target.resolve_request(["set key1 15 0 5", "check"])

# Starting time of the test
t1 = Time.now

N_THREADS.times do
    threads << Thread.new {
        CLIENTS.times do
            client = MemcachedClient.new
            client.resolve_request(["get key1"])
        end
    }
end

# Make sure every thread finishes executing
threads.each(&:join)

operations = N_THREADS * CLIENTS * 2
total_operations = ""
total_operations = "" << "Sum of connection and command operations: " << operations.to_s
num_threads = "Number of threads: " + N_THREADS.to_s
num_clients = "Number of clients: " + CLIENTS.to_s
# Test info
puts num_threads
puts num_clients
puts total_operations.to_s
puts "Total time: #{ (Time.now - t1)*1000 } ms"

puts "done"