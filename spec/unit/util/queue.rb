#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'
require 'puppet/util/queue'

class Foo
    class Bar
    end
    class BarBah
    end
end
class FooBar
end

describe Puppet::Util::Queue do
    mod = Puppet::Util::Queue

    before do
        Puppet::Util::Queue.reset
        @client = Object.new
        @client.extend Puppet::Util::Queue
    end

    context 'when determining a type name from a class' do
        it 'should handle a simple one-word class name' do
            mod.queue_type_from_class(Foo).should == :foo
        end

        it 'should handle a simple two-word class name' do
            mod.queue_type_from_class(FooBar).should == :foo_bar
        end

        it 'should handle a two-part class name with one terminating word' do
            mod.queue_type_from_class(Foo::Bar).should == :bar
        end

        it 'should handle a two-part class name with two terminating words' do
            mod.queue_type_from_class(Foo::BarBah).should == :bar_bah
        end
    end

    context 'when registering a queue client class' do
        it 'uses the proper default name logic when type is unspecified' do
            mod.register_queue_type(Foo::BarBah)
            mod.queue_type_to_class(:bar_bah).should == Foo::BarBah
        end

        it 'uses an explicit type name when provided' do
            mod.register_queue_type(Foo::BarBah, :aardvark)
            mod.queue_type_to_class(:aardvark).should == Foo::BarBah
        end

        it 'throws an exception when type names conflict' do
            mod.register_queue_type(Foo::Bar)
            lambda { mod.register_queue_type(Foo::BarBah, :bar) }.should raise_error
        end

        it 'handle multiple, non-conflicting registrations' do
            mod.register_queue_type(Foo::Bar)
            mod.register_queue_type(Foo::BarBah)
            mod.queue_type_to_class(:bar).should == Foo::Bar
            mod.queue_type_to_class(:bar_bah).should == Foo::BarBah
        end

        it 'throws an exception when type name is unknown' do
            lambda { mod.queue_type_to_class(:nope) }.should raise_error
        end
    end
end
    
