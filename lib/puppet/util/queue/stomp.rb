require 'puppet/util/queue'
require 'stomp'

# Implements the Ruby Stomp client as a queue type within the Puppet::Indirector::Queue::Client
# registry, for use with the <tt>:queue</tt> indirection terminus type.
#
# Looks to <tt>Puppet[:queue_source]</tt> for the sole argument to the underlying Stomp::Client constructor;
# consequently, for this client to work, <tt>Puppet[:queue_source]</tt> must use the Stomp::Client URL-like
# syntax for identifying the Stomp message broker: <em>login:pass@host.port</em>
class Puppet::Util::Queue::Stomp < Stomp::Client
    def initialize
        super( Puppet[:queue_source] )
    end

    def send(target, msg)
        super(stompify_target(target), msg)
    end

    def subscribe(target)
        super(stompify_target(target))
    end

    def stompify_target(target)
        '/queue/' + target
    end

    Puppet::Util::Queue.register_queue_type(self, :stomp)
end
