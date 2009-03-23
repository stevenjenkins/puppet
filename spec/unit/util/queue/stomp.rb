#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'
require 'puppet/util/queue'


def Puppet.[](*any)
    'faux_queue_source'
end

describe Puppet::Util::Queue do
    it 'should load :stomp client appropriately' do
        Puppet::Util::Queue.queue_type_to_class(:stomp).name.should == 'Puppet::Util::Queue::Stomp'
    end
end

describe 'Puppet::Util::Queue::Stomp' do
    before :all do
        class Stomp::Client
            attr_accessor :queue_source

            def send(q, m)
                'To %s: %s' % [q, m]
            end

            def subscribe(q)
                'subscribe: %s' % q
            end

            def initialize(s)
                self.queue_source = s
            end
        end
    end

    it 'should be registered with Puppet::Util::Queue as :stomp type' do
        Puppet::Util::Queue.queue_type_to_class(:stomp).should == Puppet::Util::Queue::Stomp
    end

    it 'should initialize using Puppet[:queue_source] for configuration' do
        o = Puppet::Util::Queue::Stomp.new
        o.queue_source.should == 'faux_queue_source'
    end

    it 'should transform the simple queue name to "/queue/<queue_name>"' do
        Puppet::Util::Queue::Stomp.new.stompify_target('blah').should == '/queue/blah'
    end

    it 'should transform the queue name properly and pass along to superclass for send and subscribe' do
        o = Puppet::Util::Queue::Stomp.new
        o.send('fooqueue', 'Smite!').should == 'To /queue/fooqueue: Smite!'
        o.subscribe('moodew').should == 'subscribe: /queue/moodew'
    end
end

