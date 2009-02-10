#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2007-11-1.
#  Copyright (c) 2006. All rights reserved.

require File.dirname(__FILE__) + '/../spec_helper'
require 'puppet/relationship'

describe Puppet::Relationship do
    before do
        @edge = Puppet::Relationship.new(:a, :b)
    end

    it "should have a :source attribute" do
        @edge.should respond_to(:source)
    end

    it "should have a :target attribute" do
        @edge.should respond_to(:target)
    end

    it "should have a :label attribute" do
        @edge.should respond_to(:label)
    end

    it "should provide a :ref method that describes the edge" do
        @edge = Puppet::Relationship.new("a", "b")
        @edge.ref.should == "a => b"
    end
end

describe Puppet::Relationship, " when initializing" do
    before do
        @edge = Puppet::Relationship.new(:a, :b, :testing => :foo)
    end

    it "should use the first argument as the source" do
        @edge.source.should == :a
    end

    it "should use the second argument as the target" do
        @edge.target.should == :b
    end

    it "should use the third argument as the label" do
        @edge.label.should == {:testing => :foo}
    end

    it "should require a callback if a non-NONE event is specified" do
        proc { Puppet::Relationship.new(:a, :b, :event => :something) }.should raise_error(ArgumentError)
    end

    it "should require the label to be a hash" do
        proc { Puppet::Relationship.new(:a, :b, :event) }.should raise_error(ArgumentError)
    end
end

describe Puppet::Relationship, " when interpreting the label" do
    it "should default to an event of nil" do
        @edge = Puppet::Relationship.new(:a, :b)
        @edge.event.should be_nil
    end

    it "should expose a provided event via the :event method" do
        @edge = Puppet::Relationship.new(:a, :b, :event => :something, :callback => :whatever)
        @edge.event.should == :something
    end

    it "should default to a nil callback" do
        @edge = Puppet::Relationship.new(:a, :b)
        @edge.callback.should be_nil
    end

    it "should expose a provided callback via the :callback method" do
        @edge = Puppet::Relationship.new(:a, :b, :callback => :testing)
        @edge.callback.should == :testing
    end
end

describe Puppet::Relationship, " when matching edges with no specified event" do
    before do
        @edge = Puppet::Relationship.new(:a, :b)
    end

    it "should not match :NONE" do
        @edge.should_not be_match(:NONE)
    end

    it "should not match :ALL_EVENTS" do
        @edge.should_not be_match(:NONE)
    end

    it "should not match any other events" do
        @edge.should_not be_match(:whatever)
    end
end

describe Puppet::Relationship, " when matching edges with :NONE as the event" do
    before do
        @edge = Puppet::Relationship.new(:a, :b, :event => :NONE)
    end
    it "should not match :NONE" do
        @edge.should_not be_match(:NONE)
    end

    it "should not match :ALL_EVENTS" do
        @edge.should_not be_match(:ALL_EVENTS)
    end

    it "should not match other events" do
        @edge.should_not be_match(:yayness)
    end
end

describe Puppet::Relationship, " when matching edges with :ALL as the event" do
    before do
        @edge = Puppet::Relationship.new(:a, :b, :event => :ALL_EVENTS, :callback => :whatever)
    end

    it "should not match :NONE" do
        @edge.should_not be_match(:NONE)
    end

    it "should match :ALL_EVENTS" do
        @edge.should be_match(:ALLEVENTS)
    end

    it "should match all other events" do
        @edge.should be_match(:foo)
    end
end

describe Puppet::Relationship, " when matching edges with a non-standard event" do
    before do
        @edge = Puppet::Relationship.new(:a, :b, :event => :random, :callback => :whatever)
    end

    it "should not match :NONE" do
        @edge.should_not be_match(:NONE)
    end

    it "should not match :ALL_EVENTS" do
        @edge.should_not be_match(:ALL_EVENTS)
    end

    it "should match events with the same name" do
        @edge.should be_match(:random)
    end
end

describe Puppet::Relationship, "when converting to json" do
    confine "Missing 'json' library" => Puppet.features.json?

    before do
        @edge = Puppet::Relationship.new(:a, :b, :event => :random, :callback => :whatever)
    end

    def json_output_should
        @edge.class.expects(:json_create).with { |hash| yield hash }
    end

    # LAK:NOTE For all of these tests, we convert back to the edge so we can
    # trap the actual data structure then.
    it "should set the 'json_class' to Puppet::Relationship" do
        json_output_should { |hash| hash['json_class'] == "Puppet::Relationship" }

        JSON.parse @edge.to_json
    end

    it "should store the stringified source as the source in the data" do
        json_output_should { |hash| hash['data']['source'] == "a" }

        JSON.parse @edge.to_json
    end

    it "should store the stringified target as the target in the data" do
        json_output_should { |hash| hash['data']['target'] == "b" }

        JSON.parse @edge.to_json
    end

    it "should store the jsonified label as the third item in the array" do
        json_output_should { |hash| JSON.parse(hash['data']['label']) == {"event" => "random", "callback" => "whatever"} }

        JSON.parse @edge.to_json
    end

    it "should set a label when neither the event nor callback are set" do
        @edge.label = {}

        json_output_should { |hash| hash['data']['label'].nil? }

        JSON.parse @edge.to_json
    end
end

describe Puppet::Relationship, "when converting from json" do
    confine "Missing 'json' library" => Puppet.features.json?

    before do
        @label = {
            "event" => "random",
            "callback" => "whatever"
        }
        @data = {
            "source" => "mysource",
            "target" => "mytarget",
            "label" => @label
        }
        @json = {
            "json_class" => "Puppet::Relationship",
            "data" => @data
        }
    end

    def json_result_should
        Puppet::Relationship.expects(:new).with { |*args| yield args }
    end

    # LAK:NOTE For all of these tests, we convert back to the edge so we can
    # trap the actual data structure then.
    it "should pass the source in as the first argument" do
        json_result_should { |args| args[0] == "mysource" }
        JSON.parse @json.to_json
    end

    it "should pass the target in as the second argument" do
        json_result_should { |args| args[1] == "mytarget" }
        JSON.parse @json.to_json
    end

    it "should pass the label in as a hash for the third argument" do
        json_result_should { |args| args[2] == @label }
        JSON.parse @json.to_json
    end

    it "should pass an empty hash as the label when no label is available" do
        @data.delete("label")
        json_result_should { |args| args[2] == {} }
        JSON.parse @json.to_json
    end
end
