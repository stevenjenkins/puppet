#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../spec_helper'

require 'puppet/transaction'

def without_warnings
    flag = $VERBOSE
    $VERBOSE = nil
    yield
    $VERBOSE = flag
end

describe Puppet::Transaction do
    it "should match resources by name, not title, when prefetching" do
        @catalog = Puppet::Resource::Catalog.new
        @transaction = Puppet::Transaction.new(@catalog)

        # Have both a title and name
        resource = Puppet::Type.type(:sshkey).create :title => "foo", :name => "bar", :type => :dsa, :key => "eh"
        @catalog.add_resource resource

        resource.provider.class.expects(:prefetch).with("bar" => resource)

        @transaction.prefetch
    end

    describe "when generating resources" do
        it "should finish all resources" do
            generator = stub 'generator', :depthfirst? => true
            resource = stub 'resource'

            @catalog = Puppet::Resource::Catalog.new
            @transaction = Puppet::Transaction.new(@catalog)

            generator.expects(:generate).returns [resource]

            @catalog.expects(:add_resource).yields(resource)

            resource.expects(:finish)

            @transaction.generate_additional_resources(generator, :generate)
        end

        it "should skip generated resources that conflict with existing resources" do
            generator = mock 'generator'
            resource = stub 'resource'

            @catalog = Puppet::Resource::Catalog.new
            @transaction = Puppet::Transaction.new(@catalog)

            generator.expects(:generate).returns [resource]

            @catalog.expects(:add_resource).raises(Puppet::Resource::Catalog::DuplicateResourceError.new("foo"))

            resource.expects(:finish).never
            resource.expects(:info) # log that it's skipped

            @transaction.generate_additional_resources(generator, :generate).should be_empty
        end
    end

    describe "when skipping a resource" do
        before :each do
            @resource = stub_everything 'res'
            @catalog = Puppet::Resource::Catalog.new
            @transaction = Puppet::Transaction.new(@catalog)
        end

        it "should skip resource with missing tags" do
            @transaction.stubs(:missing_tags?).returns(true)
            @transaction.skip?(@resource).should be_true
        end

        it "should skip not scheduled resources" do
            @transaction.stubs(:scheduled?).returns(false)
            @transaction.skip?(@resource).should be_true
        end

        it "should skip resources with failed dependencies" do
            @transaction.stubs(:failed_dependencies?).returns(false)
            @transaction.skip?(@resource).should be_true
        end

        it "should skip virtual resource" do
            @resource.stubs(:virtual?).returns true
            @transaction.skip?(@resource).should be_true
        end
    end

    describe 'when checking application run state' do
        before do
            without_warnings { Puppet::Application = Class.new(Puppet::Application) }
            @catalog = Puppet::Resource::Catalog.new
            @transaction = Puppet::Transaction.new(@catalog)
        end

        after do
            without_warnings { Puppet::Application = Puppet::Application.superclass }
        end

        it 'should return true for :stop_processing? if Puppet::Application.stop_requested? is true' do
            Puppet::Application.stubs(:stop_requested?).returns(true)
            @transaction.stop_processing?.should be_true
        end

        it 'should return false for :stop_processing? if Puppet::Application.stop_requested? is false' do
            Puppet::Application.stubs(:stop_requested?).returns(false)
            @transaction.stop_processing?.should be_false
        end

        describe 'within an evaluate call' do
            before do
                @resource = stub 'resource', :ref => 'some_ref'
                @catalog.add_resource @resource
                @transaction.stubs(:prepare)
                @transaction.sorted_resources = [@resource]
            end

            it 'should stop processing if :stop_processing? is true' do
                @transaction.expects(:stop_processing?).returns(true)
                @transaction.expects(:eval_resource).never
                @transaction.evaluate
            end

            it 'should continue processing if :stop_processing? is false' do
                @transaction.expects(:stop_processing?).returns(false)
                @transaction.expects(:eval_resource).returns(nil)
                @transaction.evaluate
            end
        end
    end
end

describe Puppet::Transaction, " when determining tags" do
    before do
        @config = Puppet::Resource::Catalog.new
        @transaction = Puppet::Transaction.new(@config)
    end

    it "should default to the tags specified in the :tags setting" do
        Puppet.expects(:[]).with(:tags).returns("one")
        @transaction.tags.should == %w{one}
    end

    it "should split tags based on ','" do
        Puppet.expects(:[]).with(:tags).returns("one,two")
        @transaction.tags.should == %w{one two}
    end

    it "should use any tags set after creation" do
        Puppet.expects(:[]).with(:tags).never
        @transaction.tags = %w{one two}
        @transaction.tags.should == %w{one two}
    end

    it "should always convert assigned tags to an array" do
        @transaction.tags = "one::two"
        @transaction.tags.should == %w{one::two}
    end
end
