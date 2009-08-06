#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../spec_helper.rb'
require 'puppet/events'

def silent
    flag = $VERBOSE
    $VERBOSE = false
    yield
    $VERBOSE = flag
end

describe Puppet::Events do
    before do
        @target = Puppet::Events
    end

    it 'should implement the Puppet::Events::Publisher interface' do
        @target.respond_to?(:subscribe).should be_true
        @target.respond_to?(:unsubscribe).should be_true
        @target.respond_to?(:raise_event).should be_true
        @target.respond_to?(:private_publisher?).should be_true
    end

    it 'should be a private publisher' do
        @target.private_publisher?.should be_true
    end

    describe 'propagate_event' do
        before do
            @event = stub 'event'
        end

        it 'should raise an exception if no event is provided' do
            lambda { @target.propagate_event }.should raise_error {|e| e.message ~ 'provide an event'}
        end

        it 'should pass event to each callback in sequence' do
            listener = mock 'listener'
            callback_seq = sequence 'callbacks'
            listener.expects(:one).with(@event).in_sequence(callback_seq)
            listener.expects(:two).with(@event).in_sequence(callback_seq)
            listener.expects(:three).with(@event).in_sequence(callback_seq)

            callbacks = [:one, :two, :three].collect do |sym|
                Proc.new {|e| listener.send(sym, e)}
            end

            @target.propagate_event(@event, callbacks)
        end

        it 'should notify global subscribers by default' do
            @target.expects(:notify_global_subscribers).with(@event)
            @target.propagate_event @event, []
        end

        it 'should notify global subscribers if :no_global is false' do
            @target.expects(:notify_global_subscribers).with(@event)
            @target.propagate_event @event, [], :no_global => false
        end

        it 'should not notify global subscribers if :no_global is true' do
            @target.expects(:notify_global_subscribers).never
            @target.propagate_event @event, [], :no_global => true
        end
    end

    describe 'notify_global_subscribers' do
        it 'should invoke raise_event with the provided event' do
            event = stub 'event'
            @target.expects(:raise_event).with(event)
            @target.notify_global_subscribers(event)
        end
    end
end

describe Puppet::Events::Publisher do
    before :each do
        @class = Class.new do
            include Puppet::Events::Publisher
        end

        @publisher = @class.new
    end

    describe 'private publisher flag' do
        it 'should be false by default' do
            @publisher.private_publisher?.should be_false
        end

        it 'should be true if :private_publisher class method is invoked' do
            @class.private_publisher
            @publisher.private_publisher?.should be_true
        end

        it 'should be false if :private_publisher explicitly set at class level' do
            @class.private_publisher false
            @publisher.private_publisher?.should be_false
        end
    end

    describe 'raise_event' do
        before do
            @callbacks = [:a, :b, :c]
            @event = stub 'event'
            @publisher.stubs(:subscriber_callbacks).returns(@callbacks)
        end

        it 'should invoke Puppet::Events.propagate_event with subscriber callbacks' do
            Puppet::Events.expects(:propagate_event).with(@event, @callbacks)
            @publisher.raise_event(@event)
        end

        it 'should provide propagate_event with :no_global flag if the publisher is private' do
            @publisher.stubs(:private_publisher?).returns(true)
            Puppet::Events.expects(:propagate_events).with(@event, @callbacks, {:no_global => true})
            @publisher.raise_event(@event)
        end
    end

    describe 'creating subscriber entry' do
        before do
            @subscriber = stub 'subscriber'
        end

        describe 'with a callback block' do
            it 'should pass block through unaltered' do
                block = Proc.new {|e| e}
                entry = @publisher.class.create_subscriber_entry(@subscriber, &block)
                entry.size.should == 2
                entry[1].should == block
            end

            it 'should have a weak reference to the subscriber' do
                entry = @publisher.class.create_subscriber_entry(@subscriber) {|e| e}
                entry.size.should == 2
                entry[0].should == @subscriber
                entry[0].respond_to?(:weakref_alive?).should be_true
            end
        end

        describe 'with a method name' do
            it 'should create a block that invokes the method name on a weak ref to the subscriber' do
                class << @subscriber
                    attr_accessor :weakref, :last_received

                    def callback(e)
                        self.last_received = e
                        self.weakref = self.respond_to(:weakref_alive?)
                    end
                end

                entry = @publisher.class.create_subscriber_entry(@subscriber, :callback)
                entry.size.should == 2
                event = stub 'event'
                entry[1].call(event)
                @publisher.last_received.should == event
                @publisher.weakref.should be_true
            end

            it 'should have a weak reference to the subscriber' do
                entry = @publisher.class.create_subscriber_entry(@subscriber, :callback)
                entry.size.should == 2
                entry[0].should == @publisher
                entry[0].respond_to(:weakref_alive?).should be_true
            end
        end
    end

    describe 'subscribe and unsubscribe' do
        it 'should return publisher upon success' do
            @consumer = Object.new

            result = @publisher.subscribe(@consumer) do |event|
                [self.object_id, event.object_id]
            end
            result.should == @publisher

            @publisher.unsubscribe(@consumer).should == @publisher
        end
    end

    describe 'subscribe' do
        it 'should throw an exception if subscribe invoked with both symbol and block' do
            lambda { @publisher.subscribe(Object.new, :some_method) {|x| x.object_id} }.should raise_error() {|error|
                error.message.should =~ /specify both a method and a block/
            }
        end

        it 'should get subscription entry via class.create_subscription_entry' do
            sub_a = stub 'sub_a'
            sub_b = stub 'sub_b'
            sub_seq = sequence 'sub_seq'
            a_block = Proc.new {|e| e}
            @class.expects(:create_subscription_entry).with(sub_a, a_block).in_sequence(sub_seq)
            @class.expects(:create_subscription_entry).with(sub_b, :foo).in_sequence(sub_seq)
            @publisher.subscribe(sub_a, &a_block)
            @publisher.subscribe(sub_b, :foo)
        end

        it 'should put subscription entry for method in subscriber_callbacks' do
            subscriber = mock 'subscriber'
            subscriber.expects(:foo)
            @publisher.subscribe(subscriber, :foo)
            @publisher.subscriber_callbacks.each {|cb| cb.call}
        end

        it 'should put subscription entry for block in subscriber_callbacks' do
            subscriber = mock 'subscriber'
            subscriber.expects(:in_block)
            @publisher.subscribe(subscriber) { subscriber.in_block }
            @publisher.subscriber_callbacks.each {|cb| cb.call}
        end

        it 'should put subscriber_callbacks in order of subscription' do
            callbacks = (1..5).collect do |x|
                p = Proc.new {|e| e}
                @publisher.subscribe(p, &p)
                p
            end
            
            @publisher.subscriber_callbacks.should == callbacks
        end

        it 'should remove subscriber_callbacks for subscribers who unsubscribed' do
            consumers = (1..3).collect {|x| Proc.new {|e| e} }
            consumers.each {|c| @publisher.subscribe(c, &c) }
            @publisher.unsubscribe(consumers[1])
            @publisher.subscriber_callbacks.should == [0,2].collect {|c| consumers[c]}
        end

        it 'should remove subscriber_callbacks for subscribers who passed on' do
            consumers = (1..3).collect {|x| Proc.new {|e| e} }
            consumers.each {|c| @publisher.subscribe(c, &c) }
            consumers.first.stubs(:weakref_alive?).returns(false)
            @publisher.subscriber_callbacks.should == [1,2].collect {|c| consumers[c]}
        end
    end
end
