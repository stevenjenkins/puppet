require 'puppet'
require 'weakref'

module Puppet::Events
    module Publisher
        module ClassMethods
            def private_publisher(flag = true)
                @private_publisher = flag
            end

            def private_publisher?
                ! ! @private_publisher
            end

            def create_subscriber_entry(subscriber, callback)
                subscriber = WeakRef.new(subscriber)
                {   :subscriber => subscriber, 
                    :block => (callback.respond_to?(:call) ?  callback : Proc.new { |e| subscriber.send(callback, e) } ) 
                }
            end
        end
        
        def self.included(target_class)
            target_class.extend ClassMethods
        end

        def subscriber_callbacks
            @subscriber_callbacks ||= []
        end

        def subscriber_callbacks=(val)
            @subscriber_callbacks = val
        end

        def subscribe(subscriber, method = nil, &block)
            raise ArgumentError, "Cannot call subscribe and specify both a method and a block" if method and block
            subscriber_callbacks << self.class.create_subscriber_entry(subscriber, method.nil? ? block: method)
            self
        end

        def raise_event(event)
            if private_publisher?
                Puppet::Events.propagate_event event, subscriber_callbacks, :no_global => true
            else
                Puppet::Events.propagate_event(event, subscriber_callbacks)
            end
        end

        # needs to remove all subscriptions for that subscriber -- can't just assume one subscription
        def unsubscribe(subscriber)
            subscriber_callbacks.delete_if {|subscription| subscription[:subscriber] == subscriber }
            self
        end

        def private_publisher?
            self.class.private_publisher?
        end
    end

    class << self
        include Publisher

        # force this to always be private
        def private_publisher?
            true
        end

        def propagate_event(event, callbacks, options = {})
            # Probably want something like this in the future:
            #raise ArgumentError, "Need to provide an event to propagate_event, not %s"  % event.class  unless event.class == 'Puppet::Event'
            callbacks.each do |cb|
                cb.call(event)
            end 
            Puppet::Events.notify_global_subscribers(event) unless options[:no_global]
        end

        def notify_global_subscribers(event)
            raise_event(event)
        end
    end
end
