require 'puppet/indirector/terminus'
require 'puppet/util/queue'
require 'puppet/util/queue/stomp'

# Implements the +\:queue+ abstract indirector terminus type, for storing
# model instances to a message queue, presumably for the purpose of out-of-process
# handling of changes related to the model.
#
# Relies upon Puppet::Util::Queue for registry and client object management,
# and specifies a default queue type of +:stomp+, appropriate for use with a variety of message brokers.
#
# It's up to the queue client type to instantiate itself correctly based on Puppet configuration information.
# 
# A single queue client is maintained for the abstract terminus, meaning that you can only use one type
# of queue client, one message broker solution, etc., with the indirection mechanism.
#
# Per-indirection queues are assumed, based on the indirection name.  If the +:catalog+ indirection makes
# use of this +:queue+ terminus, queue operations work against the "catalog" queue.  It is up to the queue
# client library to handle queue creation as necessary (for a number of popular queuing solutions, queue
# creation is automatic and not a concern).
#
# Ultimately, the client object against which this terminus operates is expected to implement an interface
# similar to that of Stomp::Client:
# * +new()+ should return a connected, ready-to-go client instance.  Note that no arguments are passed in.
# * +send(queue, message)+ should send the _message_ to the specified _queue_.
# * +subscribe(queue) _block_ subscribes to _queue_ and executes _block_ upon receiving a message.
# * _queue_ names are simple names independent of the message broker or client library.  No "/queue/" prefixes like in +Stomp::Client+.
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
