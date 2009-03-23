require 'puppet/util/queue'
require 'stomp'

# Implements the Ruby Stomp client as a queue type within the +Puppet::Indirector::Queue::Client+
# registry, for use with the +:queue+ indirection terminus type.
#
# Looks to +Puppet[:queue_source]+ for the sole argument to the underlying +Stomp::Client+ constructor;
# consequently, for this client to work, +Puppet[:queue_source]+ must use the +Stomp::Client+ URL-like
# syntax for identifying the Stomp message broker: _login:pass@host.port_
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
