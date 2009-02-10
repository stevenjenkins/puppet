#!/usr/bin/env ruby
#
#  Created by Luke A. Kanies on 2006-11-24.
#  Copyright (c) 2006. All rights reserved.

# subscriptions are permanent associations determining how different
# objects react to an event

# This is Puppet's class for modeling edges in its configuration graph.
# It used to be a subclass of GRATR::Edge, but that class has weird hash
# overrides that dramatically slow down the graphing.
class Puppet::Relationship
    attr_accessor :source, :target, :label

    # Return the callback
    def callback
        if label
            label[:callback]
        else
            nil
        end
    end
    
    # Return our event.
    def event
        if label
            label[:event]
        else
            nil
        end
    end
    
    def initialize(source, target, label = {})
        if label
            unless label.is_a?(Hash)
                raise ArgumentError, "Relationship labels must be a hash"
            end
            label = label.inject({}) { |hash, ary| hash[ary[0].to_sym] = ary[1]; hash }

            if label[:event] and label[:event] != :NONE and ! label[:callback]
                raise ArgumentError, "You must pass a callback for non-NONE events"
            end
        else
            label = {}
        end

        @source, @target, @label = source, target, label
    end
    
    # Does the passed event match our event?  This is where the meaning
    # of :NONE comes from. 
    def match?(event)
        if self.event.nil? or event == :NONE or self.event == :NONE
            return false
        elsif self.event == :ALL_EVENTS or event == self.event
            return true
        else
            return false
        end
    end
    
    def ref
        "%s => %s" % [source, target]
    end

    def self.json_create(json)
        data = json["data"]
        source = data["source"]
        target = data["target"]
        label = data["label"] || {}

        new(source, target, label)
    end

    def to_json(*args)
        data = {
            'source' => source.to_s,
            'target' => target.to_s
        }

        if label != {}
            data['label'] = label
        end

        {
            'json_class' => "Puppet::Relationship",
            'data' => data
        }.to_json(*args)
    end

    def to_s
        ref
    end
end
