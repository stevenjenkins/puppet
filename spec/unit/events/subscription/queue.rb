#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'
require 'puppet/events/subscription/queue'

describe Puppet::Events::Subscription::Queue do
    before do
        @class = Puppet::Events::Subscription::Queue
        @subscription = @class.new
    end

    it 'should be derived from Puppet::Events::Subscription' do
        @subscription.kind_of?(Puppet::Events::Subscription).should be_true
    end

    it 'should have an events array for queuing events' do
        @subscription.events.should == []
    end

    describe 'handle_event' do
        before do
            @event = stub 'event', :name => :some_event
        end

        it 'should place the event on the events queue' do
            @subscription.handle_event(@event)
            @subscription.events.should == [@event]
        end
    end

    describe 'has_events?' do
        it 'should return false when the events queue is empty' do
            @subscription.stubs(:events).returns([])
            @subscription.has_events?.should be_false
        end

        it 'should return true when the events queue contains something' do
            @subscription.stubs(:events).returns([:blah])
            @subscription.has_events?.should be_true
        end
    end

    describe 'process_events' do
        before do
            @events = [:a, :b, :c, :d, :e]
            @internal_events = @events.clone
            @subscription.stubs(:events).returns(@internal_events)
        end

        it 'should invoke callback block per queued event in order' do
            @found = []
            @subscription.callback = Proc.new {|event| @found << event}
            @subscription.process_events
            @found.should == @events
        end

        it 'should pop the events off the stack along the way' do
            @sizes = []
            @subscription.callback = Proc.new {|event| @sizes << @subscription.events.size}
            @subscription.process_events
            @sizes.should == (0..@events.size-1).to_a.reverse
        end

        it 'should use the locally-provided block when given' do
            call_check = mock 'call_check'
            call_check.expects(:never).never
            call_check.expects(:call_me).times(@events.size)
            @subscription.callback = Proc.new {|e| call_check.never}
            @subscription.process_events {|e| call_check.call_me}
        end
    end
end
