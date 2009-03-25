require 'puppet/node/catalog'
require 'puppet/indirector/queue'

class Puppet::Node::Catalog::Queue < Puppet::Indirector::Queue
    def to_message(request)
        # plug in Marshal usage here instead of YAML.  Take a request object and
        # convert it to a message suitable for placing on the queue.
        # Note that request has a couple of things:
        # request.key - the identifier of the object
        # request.instance - the actual model object itself
        # It should suffice to simply dump request.instance, since request.key
        # ought to be derived from request.instance.name
    end

    def from_message(message)
        # plus in Marshal usage here instead of YAML; take message and restore it to
        # an object instance, which you return.
    end
end
