require 'puppet/events/subscription'

class Puppet::Events::Subscription::Queue < Puppet::Events::Subscription
    def events
        @events ||= []
    end

    def has_events?
        events.size > 0
    end

    def handle_event(event)
    end

    def process_events
    end
end
