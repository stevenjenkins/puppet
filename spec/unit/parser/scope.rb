#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

describe Puppet::Parser::Scope do
    before :each do
        @topscope = Puppet::Parser::Scope.new()
        # This is necessary so we don't try to use the compiler to discover our parent.
        @topscope.parent = nil
        @scope = Puppet::Parser::Scope.new()
        @scope.parent = @topscope
    end

    describe "when looking up a variable" do
        it "should default to an empty string" do
            @scope.lookupvar("var").should == ""
        end

        it "should return an string when asked for a string" do
            @scope.lookupvar("var", true).should == ""
        end

        it "should return ':undefined' for unset variables when asked not to return a string" do
            @scope.lookupvar("var", false).should == :undefined
        end

        it "should be able to look up values" do
            @scope.setvar("var", "yep")
            @scope.lookupvar("var").should == "yep"
        end

        it "should be able to look up variables in parent scopes" do
            @topscope.setvar("var", "parentval")
            @scope.lookupvar("var").should == "parentval"
        end

        it "should prefer its own values to parent values" do
            @topscope.setvar("var", "parentval")
            @scope.setvar("var", "childval")
            @scope.lookupvar("var").should == "childval"
        end

        describe "and the variable is qualified" do
            before do
                @parser = Puppet::Parser::Parser.new()
                @compiler = Puppet::Parser::Compiler.new(stub("node", :name => "foonode"), @parser)
                @scope.compiler = @compiler
                @scope.parser = @parser
            end

            def create_class_scope(name)
                klass = @parser.newclass(name)
                Puppet::Parser::Resource.new(:type => "class", :title => name, :scope => @scope, :source => mock('source')).evaluate

                return @compiler.class_scope(klass)
            end

            it "should be able to look up explicitly fully qualified variables from main" do
                other_scope = create_class_scope("")

                other_scope.setvar("othervar", "otherval")

                @scope.lookupvar("::othervar").should == "otherval"
            end

            it "should be able to look up explicitly fully qualified variables from other scopes" do
                other_scope = create_class_scope("other")

                other_scope.setvar("var", "otherval")

                @scope.lookupvar("::other::var").should == "otherval"
            end

            it "should be able to look up deeply qualified variables" do
                other_scope = create_class_scope("other::deep::klass")

                other_scope.setvar("var", "otherval")

                @scope.lookupvar("other::deep::klass::var").should == "otherval"
            end

            it "should return an empty string for qualified variables that cannot be found in other classes" do
                other_scope = create_class_scope("other::deep::klass")

                @scope.lookupvar("other::deep::klass::var").should == ""
            end

            it "should warn and return an empty string for qualified variables whose classes have not been evaluated" do
                klass = @parser.newclass("other::deep::klass")
                @scope.expects(:warning)
                @scope.lookupvar("other::deep::klass::var").should == ""
            end

            it "should warn and return an empty string for qualified variables whose classes do not exist" do
                @scope.expects(:warning)
                @scope.lookupvar("other::deep::klass::var").should == ""
            end

            it "should return ':undefined' when asked for a non-string qualified variable from a class that does not exist" do
                @scope.stubs(:warning)
                @scope.lookupvar("other::deep::klass::var", false).should == :undefined
            end

            it "should return ':undefined' when asked for a non-string qualified variable from a class that has not been evaluated" do
                @scope.stubs(:warning)
                klass = @parser.newclass("other::deep::klass")
                @scope.lookupvar("other::deep::klass::var", false).should == :undefined
            end
        end
    end

    describe "when setvar is called with append=true" do
        it "should raise error if the variable is already defined in this scope" do
            @scope.setvar("var","1",nil,nil,false)
            lambda { @scope.setvar("var","1",nil,nil,true) }.should raise_error(Puppet::ParseError)
        end

        it "it should lookup current variable value" do
            @scope.expects(:lookupvar).with("var").returns("2")
            @scope.setvar("var","1",nil,nil,true)
        end

        it "it should store the concatenated string '42'" do
            @topscope.setvar("var","4",nil,nil,false)
            @scope.setvar("var","2",nil,nil,true)
            @scope.lookupvar("var").should == "42"
        end

        it "it should store the concatenated array [4,2]" do
            @topscope.setvar("var",[4],nil,nil,false)
            @scope.setvar("var",[2],nil,nil,true)
            @scope.lookupvar("var").should == [4,2]
        end

    end

    describe "when calling number?" do
        it "should return nil if called with anything not a number" do
            Puppet::Parser::Scope.number?([2]).should be_nil
        end

        it "should return a Fixnum for a Fixnum" do
            Puppet::Parser::Scope.number?(2).should be_an_instance_of(Fixnum)
        end

        it "should return a Float for a Float" do
            Puppet::Parser::Scope.number?(2.34).should be_an_instance_of(Float)
        end

        it "should return 234 for '234'" do
            Puppet::Parser::Scope.number?("234").should == 234
        end

        it "should return nil for 'not a number'" do
            Puppet::Parser::Scope.number?("not a number").should be_nil
        end

        it "should return 23.4 for '23.4'" do
            Puppet::Parser::Scope.number?("23.4").should == 23.4
        end

        it "should return 23.4e13 for '23.4e13'" do
            Puppet::Parser::Scope.number?("23.4e13").should == 23.4e13
        end

        it "should understand negative numbers" do
            Puppet::Parser::Scope.number?("-234").should == -234
        end

        it "should know how to convert exponential float numbers ala '23e13'" do
            Puppet::Parser::Scope.number?("23e13").should == 23e13
        end

        it "should understand hexadecimal numbers" do
            Puppet::Parser::Scope.number?("0x234").should == 0x234
        end

        it "should understand octal numbers" do
            Puppet::Parser::Scope.number?("0755").should == 0755
        end

        it "should return nil on malformed integers" do
            Puppet::Parser::Scope.number?("0.24.5").should be_nil
        end

        it "should convert strings with leading 0 to integer if they are not octal" do
            Puppet::Parser::Scope.number?("0788").should == 788
        end

        it "should convert strings of negative integers" do
            Puppet::Parser::Scope.number?("-0788").should == -788
        end

        it "should return nil on malformed hexadecimal numbers" do
            Puppet::Parser::Scope.number?("0x89g").should be_nil
        end
    end
end
