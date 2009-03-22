#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'
require 'puppet/indirector/queue'

class Puppet::Indirector::Queue::TestClient
    def self.queues
        @queues ||= {}
    end

    def subscribe(queue)
        stack = self.class.queues[queue] ||= []
        while stack.length > 0 do
            yield(stack.shift)
        end
    end

    def send(queue, message)
        stack = self.class.queues[queue] ||= []
        stack.push(message)
        queue
    end

    Puppet::Util::Queue.register_queue_type(self)
end

class FooExampleData
    attr_accessor :name
end

describe Puppet::Indirector::Queue do
    before :each do
        @indirection = stub 'indirection', :name => :my_queue, :register_terminus_type => nil
        Puppet::Indirector::Indirection.stubs(:instance).with(:my_queue).returns(@indirection)
        @store_class = Class.new(Puppet::Indirector::Queue) do
            def self.to_s
                'MyQueue::MyType'
            end
        end
        @store = @store_class.new

        @subject_class = FooExampleData
        @subject = @subject_class.new
        @subject.name = :me

        Puppet.settings.stubs(:value).returns("bogus setting data")
        Puppet.settings.stubs(:value).with(:queue_client).returns(:test_client)

        @request = stub 'request', :key => :me, :instance => @subject
    end

    it 'should use the correct client type and queue' do
        @store.queue.should == :my_queue
        @store.client.should be_an_instance_of(Puppet::Indirector::Queue::TestClient)
    end

    it 'should save and restore with the appropriate queue, and handle subscribe block' do
        @subject_two = @subject_class.new
        @subject_two.name = :too
        @store.save(@request)
        @store.save(stub('request_two', :key => 'too', :instance => @subject_two))

        received = []
        @store.subscribe do |obj|
            received.push(obj)
        end

        received[0].name.should == @subject.name
        received[1].name.should == @subject_two.name
    end
end

