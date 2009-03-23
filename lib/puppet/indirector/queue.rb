require 'puppet/indirector/terminus'
require 'puppet/util/queue'

# Implements the <tt>:queue</tt> abstract indirector terminus type, for storing
# model instances to a message queue, presumably for the purpose of out-of-process
# handling of changes related to the model.
#
# Relies upon Puppet::Util::Queue for registry and client object management,
# and specifies a default queue type of <tt>:stomp</tt>, appropriate for use with a variety of message brokers.
#
# It's up to the queue client type to instantiate itself correctly based on Puppet configuration information.
# 
# A single queue client is maintained for the abstract terminus, meaning that you can only use one type
# of queue client, one message broker solution, etc., with the indirection mechanism.
#
# Per-indirection queues are assumed, based on the indirection name.  If the <tt>:catalog</tt> indirection makes
# use of this <tt>:queue</tt> terminus, queue operations work against the "catalog" queue.  It is up to the queue
# client library to handle queue creation as necessary (for a number of popular queuing solutions, queue
# creation is automatic and not a concern).
class Puppet::Indirector::Queue < Puppet::Indirector::Terminus
    extend ::Puppet::Util::Queue
    self.queue_type_default = :stomp

    # Place the request on the queue
    def save(request)
        begin
            client.send(queue, to_message(request))
        rescue => detail
            raise Puppet::Error, "Could not write %s to queue: %s" % [request.key, detail]
        end
    end

    def queue
        self.class.indirection_name
    end

    # Returns the singleton queue client object.
    def client
        self.class.client
    end

    # Formats the model instance associated with _request_ appropriately for message delivery.
    # Uses YAML serialization.
    def to_message(request)
        YAML.dump(request.instance)
    end

    # converts the _message_ from deserialized format to an actual model instance.
    def from_message(message)
        YAML.load(message)
    end

    # Provides queue subscription functionality; for a given indirection, use this method on the terminus
    # to subscribe to the indirection-specific queue.  Your _block_ will be executed per new indirection
    # model received from the queue, with _obj_ being the model instance.
    def subscribe
        client.subscribe(queue) do |msg|
            begin
                yield(from_message(msg))
            rescue => detail
                # really, this should log the exception rather than raise it all the way up the stack;
                # we don't want exceptions resulting from a single message bringing down a listener
                raise Puppet::Error, "Error occured with subscription to queue %s for indirection %s: %s" % [queue, self.class.indirection_name, detail]
            end
        end
    end
end
