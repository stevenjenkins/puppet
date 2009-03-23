
require 'puppet/indirector'
require 'puppet/util/instance_loader'

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
#       extend ::Puppet::Util::Queue
#
#       # specify the default client type to use.
#       self.queue_type_default = :special_magical_type
#   end
#
# +Queue::Fue+ instances can get a message queue client through the registry through the mixed-in method
# +client+, which will return a class-wide singleton client instance, determined by +client_class+.
module Puppet::Util::Queue
    extend Puppet::Util::InstanceLoader
    attr_accessor :queue_type_default
    instance_load :queue_clients, 'puppet/util/queue'

    def self.register_queue_type(klass, type)
        instance_hash(:queue_clients)[type] = klass
    end

    # Given a queue type symbol, returns the associated +Class+ object.  If the queue type is unknown
    # (meaning it hasn't been registered with this module), an exception is thrown.
    def self.queue_type_to_class(type)
        loaded_instance :queue_clients, type
    end

    # The class object for the client to be used, determined by queue configuration
    # settings and known queue client types.
    # Looked to the +:queue_client+ configuration entry in the running application for
    # the default queue type to use, and fails over to +queue_type_default+ if the configuration
    # information is not present.
    def client_class
        ::Puppet::Util::Queue.queue_type_to_class(::Puppet[:queue_client] || queue_type_default)
    end

    # Returns (instantiating as necessary) the singleton queue client instance, according to the
    # client_class.  No arguments go to the client class constructor, meaning its up to the client class
    # to know how to determine its queue message source (presumably through Puppet configuration data).
    def client
        @client ||= client_class.new
    end
end
