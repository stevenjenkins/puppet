# Implements a message queue client type registry for use by the indirector facility.
# Client modules for speaking a particular protocol (e.g. Stomp::Client for Stomp message
# brokers, Memcached for Starling and Sparrow, etc.) register themselves with this module.
# 
# A given client class registers itself:
#   class Puppet::Indirector::Queue:SpecialMagicalClient < Messaging::SpecialMagic
#       ...
#   end
#   Puppet::Indirector::Queue::Client.register_queue_type_class(Puppet::Indirector::Queue::SpecialMagicalClient)
#
# This module reduces the rightmost segment of the class name into a pretty symbol that will
# serve as the queuing client's name.  Which means that the "SpecialMagicalClient" above will
# be named _:special_magical_client_ within the registry.
#
# Another class/module may mix-in this module, and may then make use of the registered clients.
#   class Queue::Fue
#       # mix it in at the class object level rather than instance level
#       extend ::Puppet::Indirector::Queue::Client
#
#       # specify the default client type to use.
#       self.queue_type_default = :special_magical_type
#   end
#
# +Queue::Fue+ instances can get a message queue client through the registry through the mixed-in method
# +client+, which will return a class-wide singleton client instance, determined by +client_class+.
module Puppet::Indirector::Queue::Client
    attr_accessor :queue_client_types, :queue_type_default

    @queue_client_types = {}

    # The class object for the client to be used, determined by queue configuration
    # settings and known queue client types.
    # Looked to the +:queue_client+ configuration entry in the running application for
    # the default queue type to use, and fails over to +queue_type_default+ if the configuration
    # information is not present.
    def client_class
        queue_type_to_class(::Puppet[:queue_client] || queue_type_default)
    end

    # Given a queue type symbol, returns the associated +Class+ object.  If the queue type is unknown
    # (meaning it hasn't been registered with this module), an exception is thrown.
    def queue_type_to_class(type)
        class_obj = queue_client_types[:type]
        raise Puppet::Error, "Could not locate class for queue type %s" % type.to_s unless class_obj
        class_obj
    end

    # Adds a new class/queue-type pair to the registry.  The _type_ argument is optional; if not provided,
    # _type_ defaults to a lowercased, underscored symbol programmatically derived from the rightmost
    # namespace of _klass.name_.
    #
    #   # register with default name +:you+
    #   register_queue_type(Foo::You)
    #   
    #   # register with explicit queue type name +:myself+
    #   register_queue_type(Foo::Me, :myself)
    #
    # If the type is already registered, an exception is thrown.  No checking is performed of _klass_,
    # however; a given class could be registered any number of times, as long as the _type_ differs with
    # each registration.
    def register_queue_type(klass, type)
        type ||= queue_type_from_class(klass)
        raise Puppet::Error, "Queue type %s is already registered" % type.to_s if queue_client_types[type]
        queue_client_types[type] = klass
    end

    # Given a class object _klass_, returns the programmatic default queue type name symbol for _klass_.
    # The algorithm is as shown in earlier examples; the last namespace segment of _klass.name_ is taken
    # and converted from mixed case to underscore-separated lowercase, and interned.
    #   queue_type_from_class(Foo) -> :foo
    #   queue_type_from_class(Foo::Too) -> :too
    #   queue_type_from_class(Foo::ForYouTwo) -> :for_you_too
    #
    # The implicit assumption here, consistent with other pieces of Puppet and +Puppet::Indirector+ in
    # particular, is that all your client modules live in the same namespace, such that reduction to
    # a flat namespace of symbols is reasonably safe.
    def queue_type_from_class(klass)
        # convert last segment of classname from studly caps to lower case with underscores, and symbolize
        klass.name.split('::').pop.sub(/^[A-Z]/, '\1'.downcase).gsub(/[A-Z]/) {|c| '_' + c.downcase }.intern
    end

    # Returns (instantiating as necessary) the singleton queue client instance, according to the
    # client_class.  No arguments go to the client class constructor, meaning its up to the client class
    # to know how to determine its queue message source (presumably through Puppet configuration data).
    def client
        @client ||= client_class.new
    end
end
