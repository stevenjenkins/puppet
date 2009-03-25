require 'puppet'
require 'puppet/application'
require 'puppet/rails/host'
require 'rubygems'
require 'activerecord'
require 'stomp'

Puppet::Application.new(:puppetqd) do

    should_parse_config

    option("--queuesource","-qs")
    option("--debug","-d")
    option("--verbose","-v")
    option("--storeconfigs","-sc")

    unknown do {opt,arg}
      true
    end 

    preinit do
       @foo = false
   end 

   dispatch do
      ARGV.shift
   end
    setup do
        Puppet::Log.newdestination(:console)
        Puppet::Log.level = :debug
	trap(:INT) do
	  $stderr.puts "Cancelling"
          exit(1)
	end
    end

    def main 
        puts "Entered main"
	# Puppet.parse_config
	# if Puppet[:storeconfigs]	
        if true
          puts "Storeconfigs set"
	  ActiveRecord::Base.verify_active_connections!
          dbargs = {:adapter => 'sqlite3',
                    :dbfile => '/var/lib/puppet/storeconfigs.sqlite' }
	  begin
          ActiveRecord::Base.establish_connection(dbargs)
          puts "ActiveRecord connection established"
          rescue => detail
             puts detail.backtrace
            exit(1)
         end

         # username, password, host, port 
	 #c = Stomp::Client.open "brianm", "s3kr3t", "localhost", 61613 
	 c = Stomp::Client.open "stomp://localhost:61613" 
         puts "Connected to Stomp"
	 # block will be called for each message received from the destination 
	 c.subscribe "/queue/storeconfig" do |message| 
	   host = Marshal.restore(message.body)
	   # puts "received: #{host.name} on #{message.headers['destination']}" 
           puts "received: #{host.name} on #{message.headers['destination']}" 
	   host.save
	 end  # subscribe
         # wait for somebody to send us a kill signal
         while true
            sleep 1
         end
      end # storeconfigs
    end #main
end # class

