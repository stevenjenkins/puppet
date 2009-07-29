require 'weakref'

module Puppet
  module Events
    module Publisher
      def subscribe(consumer, *method, &callback)
        consumer = WeakRef.new(consumer)
        subscription = [consumer]
        if method.size > 0
          method = method.first
          subscription << Proc.new {|*e| consumer.__send__(method, *e)}
        end

        if block_given?
          raise 'subscribe() cannot specify both a method and a block!' if subscription.size > 1
          subscription << callback
        end

        subscriptions << subscription
        self
      end

      def unsubscribe(consumer)
        subscriptions.reject! do |subscription|
          subscription[0] == consumer
        end
        self
      end

      def raise_event(event)
        subscriptions.each do |subscription|
          subscription[1].call(event) if subscription[0].weakref_alive?
        end
        self
      end

      def subscriptions
        @subscriptions ||= []
      end

      private :subscriptions
    end
  end
end
