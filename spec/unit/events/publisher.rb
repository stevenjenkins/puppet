#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'
require 'puppet/events/publisher'

describe Puppet::Events::Publisher do
  before :each do
    @class = Class.new do
      include Puppet::Events::Publisher
    end

    @publisher = @class.new
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

    it 'should throw an exception if subscribe invoked with both symbol and block' do
      lambda { @publisher.subscribe(Object.new, :some_method) {|x| x.object_id} }.should raise_error() {|error|
        error.message.should =~ /specify both a method and a block/
      }
    end
  end

  describe 'raise_event' do
    it 'should pass event to a subscriber block when subscription performed with block rather than method symbol' do
      consumer = Object.new
      stack = []
      @publisher.subscribe(consumer) do |event|
        stack << [consumer.object_id, event.object_id]
      end
      e = Object.new
      @publisher.raise_event(e)
      
      stack.size.should == 1
      stack.first.should == [consumer.object_id, e.object_id]
    end

    it 'should pass event to subscriber method when method specified' do
      consumer = Object.new
      stack = []
      class << consumer
        attr_accessor :stack
        def handle_event(event)
          stack << [event, self]
        end
      end
      consumer.stack = stack
      @publisher.subscribe(consumer, :handle_event)
      e = Object.new
      @publisher.raise_event(e)
      stack.size.should == 1
      stack.first.should == [e, consumer]
    end

    it 'should broadcast in order of subscription' do
      consumer = Object.new
      stack = []
      @publisher.subscribe(consumer) {|e| stack << :first}
      @publisher.subscribe(consumer) {|e| stack << :second}
      @publisher.subscribe(consumer) {|e| stack << :third}
      @publisher.raise_event(Object.new)
      stack.size.should == 3
      stack.should == [:first, :second, :third]
    end

    it 'should skip subscribers who have unsubscribed' do
      stack = []
      consumers = (1..3).collect {|x| Object.new}
      consumers.each {|c| @publisher.subscribe(c) {|e| stack << c.object_id} }
      @publisher.unsubscribe(consumers[1])
      @publisher.raise_event(Object.new)
      stack.should == [0,2].collect {|i| consumers[i].object_id}
    end

    it 'should gracefully handle subscribers that have passed on' do
      gc = GC.enable
      stack = []
      consumer_class = Class.new do
        attr_accessor :stack
        def handle_event(event)
          puts "Handling event!"
          stack << object_id
        end
      end
      consumers = (1..3).collect {|x| consumer_class.new}
      consumers.each {|c| c.stack = stack; @publisher.subscribe(c, :handle_event)}
      consumers.delete_at(1)
      ObjectSpace.garbage_collect
      @publisher.raise_event(Object.new)
      stack.size.should == 2
      stack.should == consumers.collect {|c| c.object_id}
      GC.disable if gc
    end
  end
end
