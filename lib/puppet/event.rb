
#require 'puppet'
#require 'puppet/util/methodhelper'
#require 'puppet/util/errors'

# events are packets of information; they result in one or more (or none)
# subscriptions getting triggered, and then they get cleared
class Puppet::Event
    include Puppet::Util::MethodHelper
    include Puppet::Util::Errors

    attr_reader  :name,          # e.g., 'file_changed'
        :source,        # resource that triggered the event: e.g., File[/foo]
        :timestamp,     # assumes time values are useful; e.g., running NTP
        :node,          # host generating the event
        :application,   # puppetd, puppetmasterd, puppetqd, an application, etc
        :description,   # the actual message
        :identifier,    # unique across all nodes
        :level,         # like syslog level: notice, info, warning, error, etc
        :parent_event   # optional

    def initialize(name, source)
        @name, @source = name, source
        @timestamp = Time.now
        # This is not sufficient, but is a start
        @identifier =  "#{@node} #{@name} #{@timestamp}"
    end

    def to_s
        "#{@timestamp} #{@node} #{@identifier} #{@source.to_s} #{@name.to_s}"
    end

    # There is a better way to do this
    def info
        Log('info', self.to_s())
    end

    def warn
        Log('warn', self.to_s())
    end

    def err
        Log('err', self.to_s())
    end
end
