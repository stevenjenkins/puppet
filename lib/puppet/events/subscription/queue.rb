require 'puppet/events/subscription'

class Puppet::Events::Subscription::Queue < Puppet::Events::Subscription
    def events
        @events ||= []
    end

    def callback
        @callback
    end

    def callback=(val)
        @callback = val
    end

    def has_events?
        events.size > 0
    end

    def handle_event(event)
        events << event
    end

    def process_events(&block)
        while (e = events.shift)
            block ? block.call(e) : self.callback.call(e)
        end
    end
end
