#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'
require 'puppet/util/queue'
require 'spec/mocks'

describe Puppet::Util::Queue do
    before :each do
        @client_classes = { :default => Class.new, :setup => Class.new }
        @class = Class.new do
            extend Puppet::Util::Queue
            self.queue_type_default = :default
        end
        Puppet::Util::Queue.stubs(:loaded_instance).with(:queue_clients, :default).returns(@client_classes[:default])
        Puppet::Util::Queue.stubs(:loaded_instance).with(:queue_clients, :setup).returns(@client_classes[:setup])
    end

    it 'returns client class based on queue_type_default' do
        Puppet.settings.stubs(:value).returns(nil)
        @class.client_class.should == @client_classes[:default]
        @class.client.class.should == @client_classes[:default]
    end

    it 'prefers settings variable for client class when specified' do
        Puppet.settings.stubs(:value).with(:queue_client).returns(:setup)
        @class.client_class.should == @client_classes[:setup]
        @class.client.class.should == @client_classes[:setup]
    end
end
