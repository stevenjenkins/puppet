require 'puppet'

module Puppet::Events
    module Publisher
        module ClassMethods
            def private_publisher(flag = true)
                @private_publisher = flag
            end

            def private_publisher?
                ! ! @private_publisher
            end

            def create_subscriber_entry(subscriber, method = nil, &block)
            end
        end

        def self.included(target_class)
            target_class.extend ClassMethods
        end

        def subscriber_callbacks
        end

        def subscribe(subscriber, method = nil, &block)
        end

        def raise_event(event)
        end

        def unsubscribe(subscriber)
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
        end

        def notify_global_subscribers(event)
        end
    end
end
