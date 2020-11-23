require 'memcached_client'
require 'memcached_server'

RSpec.describe MemcachedServer, " Command tests" do
    # CHECK COMMAND LINE FORMAT (Number of arguments, correct data types for each argument)
    subject { MemcachedClient.new } 
    context "Command validity check" do
        it "Check command validity: \"asdfasdf!\"" do
            var = subject.resolve_request(["asdfasdf!"])
            expect(var).to eq("ERROR\n")
        end
    end
    context "Command validity check" do
        subject { MemcachedClient.new }
        it "Check command validity: \"set ls ks\", wrong number of commands" do
            var = subject.resolve_request(["set ls ks"])
            expect(var).to eq("ERROR\n")
        end
    end
    context "Command validity check" do
        subject { MemcachedClient.new }
        it "Check command validity: \"set ls ks df 5\", wrong argument format (non integer flags, ttl)" do
            var = subject.resolve_request(["set ls ks df 5"])
            expect(var).to eq("CLIENT_ERROR bad command line format\n")
        end
    end
    context "Command validity check" do
        subject { MemcachedClient.new }
        it "Check command validity: \"set ls 5 sdf 5\", wrong argument format (non integer ttl)" do
            var = subject.resolve_request(["set ls 5 sdf 5"])
            expect(var).to eq("CLIENT_ERROR bad command line format\n")
        end
    end
    context "Command validity check" do
        subject { MemcachedClient.new }
        it "Check command validity: \"set 135 5 0 a\", wrong argument format (non integer data_block length)" do
            var = subject.resolve_request(["set 135 5 0 a"])
            expect(var).to eq("CLIENT_ERROR bad command line format\n")
        end
    end
    context "Command validity check" do
        subject { MemcachedClient.new }
        it "Check command validity: \"set 135 dfs 0 7\", wrong argument format (non integer flags)" do
            var = subject.resolve_request(["set 135 5 0 a"])
            expect(var).to eq("CLIENT_ERROR bad command line format\n")
        end
    end
    context "Command validity check" do
        subject { MemcachedClient.new }
        it "Check command validity: \"set 135 dfs fc w1\", wrong argument format (non integer flags, ttl, length)" do
            var = subject.resolve_request(["set 135 5 0 a"])
            expect(var).to eq("CLIENT_ERROR bad command line format\n")
        end
    end
    context "Command validity check" do
        subject { MemcachedClient.new }
        it "Check command validity: \"replace 135 dfs fc w1\", wrong argument format, different command" do
            var = subject.resolve_request(["set 135 5 0 a"])
            expect(var).to eq("CLIENT_ERROR bad command line format\n")
        end
    end
    context "Command validity check" do
        subject { MemcachedClient.new }
        it "Check command validity: \"add 135 dfs fc w1\", wrong argument format, different command" do
            var = subject.resolve_request(["set 135 5 0 a"])
            expect(var).to eq("CLIENT_ERROR bad command line format\n")
        end
    end
    # CHECK set COMMAND PROPER OPERATION
    context "set Command validity check" do
        subject { MemcachedClient.new }
        it "Check set command validity, correct command format and value" do
            var = subject.resolve_request(["set key1 15 0 5", "check"])
            expect(var).to eq("STORED\n")
        end
    end
    context "set Command validity check" do
        subject { MemcachedClient.new }
        it "Check set command validity, correct command format and value, replace previous key" do
            var = subject.resolve_request(["set key1 15 0 5", "check"])
            expect(var).to eq("STORED\n")
        end
    end
    context "set Command validity check" do
        subject { MemcachedClient.new }
        # "Noreply check would be for a future version, since there is no server response to compare to"
        it "Check set command validity, correct command format and value, maximum number or arguments" do
            var = subject.resolve_request(["set key2 15 0 5 badnorepl", "check"])
            expect(var).to eq("STORED\n")
        end
    end
    # CHECK add COMMAND PROPER OPERATION
    # Proper checking of this command requires server reset
    context "add Command validity check" do
        subject { MemcachedClient.new }
        it "Check add command validity, correct command format and value, nonexistent key" do
            var = subject.resolve_request(["add newest_key 15 0 5", "check"])
            expect(var).to eq("STORED\n")
        end
    end
    context "add Command validity check" do
        subject { MemcachedClient.new }
        it "Check add command validity, correct command format and value, existent key" do
            var = subject.resolve_request(["add newest_key 15 0 5", "check"])
            expect(var).to eq("NOT STORED\n")
        end
    end
    # CHECK replace COMMAND PROPER OPERATION
    # Proper checking of this command requires server reset
    context "replace Command validity check" do
        subject { MemcachedClient.new }
        it "Check replace command validity, correct command format and value, nonexistent key" do
            var = subject.resolve_request(["replace newest_key2 15 0 5", "check"])
            expect(var).to eq("NOT STORED\n")
        end
    end
    context "replace Command validity check" do
        subject { MemcachedClient.new }
        it "Check replace command validity, correct command format and value, existent key" do
            var = subject.resolve_request(["replace key1 15 0 5", "check"])
            expect(var).to eq("STORED\n")
        end
    end
    # CHECK append COMMAND PROPER OPERATION
    # Proper checking of this command requires server reset
    context "append Command validity check" do
        subject { MemcachedClient.new }
        it "Check append command validity, correct command format and value, nonexistent key" do
            var = subject.resolve_request(["append no_key 15 0 5", "check"])
            expect(var).to eq("NOT STORED\n")
        end
    end
    context "append Command validity check" do
        subject { MemcachedClient.new }
        it "Check append command validity, correct command format and value, existent key" do
            var = subject.resolve_request(["append key1 15 0 5", "check"])
            expect(var).to eq("STORED\n")
        end
    end
    # CHECK prepend COMMAND PROPER OPERATION
    # Proper checking of this command requires server reset
    context "prepend Command validity check" do
        subject { MemcachedClient.new }
        it "Check prepend command validity, correct command format and value, nonexistent key" do
            var = subject.resolve_request(["prepend no_key2 15 0 5", "good_"])
            expect(var).to eq("NOT STORED\n")
        end
    end
    context "prepend Command validity check" do
        subject { MemcachedClient.new }
        it "Check prepend command validity, correct command format and value, existent key" do
            var = subject.resolve_request(["prepend key2 15 0 5", "good_"])
            expect(var).to eq("STORED\n")
        end
    end
    # CHECK cas COMMAND PROPER OPERATION
    # Proper checking of this command requires server reset
    context "cas Command validity check" do
        subject { MemcachedClient.new }
        it "Check cas command validity, correct command format and value, nonexistent key" do
            var = subject.resolve_request(["cas no_key3 15 0 5 1", "good_"])
            expect(var).to eq("NOT FOUND\n")
        end
    end
    context "cas Command validity check" do
        subject { MemcachedClient.new }
        it "Check cas command validity, correct command format and value, existent key, wrong cas id" do
            var = subject.resolve_request(["cas key2 15 0 5 1", "good_"])
            expect(var).to eq("EXISTS\n")
        end
    end
    context "cas Command validity check" do
        subject { MemcachedClient.new }
        it "Check cas command validity, correct command format and value, existent key, correct cas id" do
            var = subject.resolve_request(["cas newest_key 15 0 5 4", "good_"])
            expect(var).to eq("STORED\n")
        end
    end
    # CHECK get COMMAND PROPER OPERATION
    # Proper checking of this command requires server reset
    context "get Command validity check" do
        subject { MemcachedClient.new }
        it "Check get command validity, correct command format and value, nonexistent key" do
            var = subject.resolve_request(["get no_key4"])
            expect(var).to eq("END\n")
        end
    end
    context "get Command validity check" do
        subject { MemcachedClient.new }
        it "Check get command validity, correct command format and value, existent key, validate append" do
            var = subject.resolve_request(["get key1"])
            expect(var).to eq("VALUE key1 15 10\ncheckcheck\nEND\n")
        end
    end
    context "get Command validity check" do
        subject { MemcachedClient.new }
        it "Check get command validity, correct command format and value, existent key, validate prepend" do
            var = subject.resolve_request(["get key2"])
            expect(var).to eq("VALUE key2 15 10\ngood_check\nEND\n")
        end
    end
    context "get Command validity check" do
        subject { MemcachedClient.new }
        it "Check get command validity, correct command format and value, existent key, 2 keys" do
            var = subject.resolve_request(["get key1 key2"])
            expect(var).to eq("VALUE key1 15 10\ncheckcheck\nVALUE key2 15 10\ngood_check\nEND\n")
        end
    end
    context "get Command validity check" do
        subject { MemcachedClient.new }
        it "Check get command validity, correct command format and value, existent key, 2 keys, swap positions" do
            var = subject.resolve_request(["get key2 key1"])
            expect(var).to eq("VALUE key2 15 10\ngood_check\nVALUE key1 15 10\ncheckcheck\nEND\n")
        end
    end
    context "get Command validity check" do
        subject { MemcachedClient.new }
        it "Check get command validity, correct command format and value, existent key, 2 existent keys, ignore nonexistent key" do
            var = subject.resolve_request(["get key1 nonexistent_key key2"])
            expect(var).to eq("VALUE key1 15 10\ncheckcheck\nVALUE key2 15 10\ngood_check\nEND\n")
        end
    end
    # CHECK gets COMMAND PROPER OPERATION
    # Proper checking of this command requires server reset
    context "gets Command validity check" do
        subject { MemcachedClient.new }
        it "Check gets command validity, correct command format and value, nonexistent key" do
            var = subject.resolve_request(["gets no_key9"])
            expect(var).to eq("END\n")
        end
    end
    context "gets Command validity check" do
        subject { MemcachedClient.new }
        it "Check gets command validity, correct command format and value, existent key" do
            var = subject.resolve_request(["gets newest_key"])
            expect(var).to eq("VALUE newest_key 15 5 8\ngood_\nEND\n")
        end
    end
    

end