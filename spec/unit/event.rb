#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../spec_helper'

require 'puppet/event'

describe Puppet::Event do
    Event = Puppet::Event

    before do
    #    @source = Event::Action.new('foo', 'create')
        @sample = Event.new(@source, "bar")
    end

    it "should require a name and a source" do
        lambda { Event.new }.should raise_error(ArgumentError)
    end

    it "should have a name getter" do
        Event.new(:foo, "bar").name.should == :foo
    end

    it "should have a timestamp accessor and set its timestamp appropriately" do
        time = stubs 'time'
        Time.expects(:now).returns time
        Event.new(:foo, "bar").timestamp.should equal(time)
    end

    #it "should raise an error if the source is not an Event::Action" do
    #    lambda { Event.new(:foo, 'bar')}.should raise_error 
    #end

    it "should have a source accessor" do
        Event.new(:foo, "bar").source.should == "bar"
    end

    it "should produce a string containing the event name and the source" do
        Event.new(:event, :source).to_s.should =~ /source event/
    end

    it "should respond to to_json" do
        @sample.should respond_to(:to_json)
    end

    it "should equal itself" do
        time = stub 'time'
        Time.expects(:now).returns time
        e1 = Event.new(:foo, "bar")
        e1.should equal(e1) 
    end

    it "should create a new event for a duplicate action" do
        time = stub 'time'
        Time.expects(:now).at_least_once.returns time
        e1 = Event.new(:foo, "bar")
        e2 = Event.new(:foo, "bar")
        e1.should_not equal(e2) 
    end
end
