Puppet::Type.newtype(:tidy) do
    require 'puppet/file_serving/fileset'

    @doc = "Remove unwanted files based on specific criteria.  Multiple
        criteria are OR'd together, so a file that is too large but is not
        old enough will still get tidied.

        If you don't specify either 'age' or 'size', then all files will
        be removed.

        This resource type works by generating a file resource for every file
        that should be deleted and then letting that resource perform the
        actual deletion.
        "

    newparam(:path) do
        desc "The path to the file or directory to manage.  Must be fully
            qualified."
        isnamevar
    end

    newparam(:matches) do
        desc "One or more (shell type) file glob patterns, which restrict
            the list of files to be tidied to those whose basenames match
            at least one of the patterns specified. Multiple patterns can
            be specified using an array.

            Example::

                    tidy { \"/tmp\":
                        age => \"1w\",
                        recurse => false,
                        matches => [ \"[0-9]pub*.tmp\", \"*.temp\", \"tmpfile?\" ]
                    }

            This removes files from \/tmp if they are one week old or older,
            are not in a subdirectory and match one of the shell globs given.

            Note that the patterns are matched against the
            basename of each file -- that is, your glob patterns should not
            have any '/' characters in them, since you are only specifying
            against the last bit of the file."

        # Make sure we convert to an array.
        munge do |value|
            value = [value] unless value.is_a?(Array)
            value
        end

        # Does a given path match our glob patterns, if any?  Return true
        # if no patterns have been provided.
        def tidy?(path, stat)
            basename = File.basename(path)
            flags = File::FNM_DOTMATCH | File::FNM_PATHNAME
            return true if value.find {|pattern| File.fnmatch(pattern, basename, flags) }
            return false
        end
    end

    newparam(:backup) do
        desc "Whether tidied files should be backed up.  Any values are passed
            directly to the file resources used for actual file deletion, so use
            its backup documentation to determine valid values."
    end

    newparam(:age) do
        desc "Tidy files whose age is equal to or greater than
            the specified time.  You can choose seconds, minutes,
            hours, days, or weeks by specifying the first letter of any
            of those words (e.g., '1w').

            Specifying 0 will remove all files."

        @@ageconvertors = {
            :s => 1,
            :m => 60
        }

        @@ageconvertors[:h] = @@ageconvertors[:m] * 60
        @@ageconvertors[:d] = @@ageconvertors[:h] * 24
        @@ageconvertors[:w] = @@ageconvertors[:d] * 7

        def convert(unit, multi)
            if num = @@ageconvertors[unit]
                return num * multi
            else
                self.fail "Invalid age unit '%s'" % unit
            end
        end

        def tidy?(path, stat)
            # If the file's older than we allow, we should get rid of it.
            if (Time.now.to_i - stat.send(resource[:type]).to_i) > value
                return true
            else
                return false
            end
        end

        munge do |age|
            unit = multi = nil
            case age
            when /^([0-9]+)(\w)\w*$/
                multi = Integer($1)
                unit = $2.downcase.intern
            when /^([0-9]+)$/
                multi = Integer($1)
                unit = :d
            else
                self.fail "Invalid tidy age %s" % age
            end

            convert(unit, multi)
        end
    end

    newparam(:size) do
        desc "Tidy files whose size is equal to or greater than
            the specified size.  Unqualified values are in kilobytes, but
            *b*, *k*, and *m* can be appended to specify *bytes*, *kilobytes*,
            and *megabytes*, respectively.  Only the first character is
            significant, so the full word can also be used."

        @@sizeconvertors = {
            :b => 0,
            :k => 1,
            :m => 2,
            :g => 3
        }

        def convert(unit, multi)
            if num = @@sizeconvertors[unit]
                result = multi
                num.times do result *= 1024 end
                return result
            else
                self.fail "Invalid size unit '%s'" % unit
            end
        end

        def tidy?(path, stat)
            if stat.size > value
                return true
            else
                return false
            end
        end

        munge do |size|
            case size
            when /^([0-9]+)(\w)\w*$/
                multi = Integer($1)
                unit = $2.downcase.intern
            when /^([0-9]+)$/
                multi = Integer($1)
                unit = :k
            else
                self.fail "Invalid tidy size %s" % age
            end

            convert(unit, multi)
        end
    end

    newparam(:type) do
        desc "Set the mechanism for determining age."

        newvalues(:atime, :mtime, :ctime)

        defaultto :atime
    end

    newparam(:recurse) do
        desc "If target is a directory, recursively descend
            into the directory looking for files to tidy."

        newvalues(:true, :false, :inf, /^[0-9]+$/)

        # Replace the validation so that we allow numbers in
        # addition to string representations of them.
        validate { |arg| }
        munge do |value|
            newval = super(value)
            case newval
            when :true, :inf; true
            when :false; false
            when Integer, Fixnum, Bignum; value
            when /^\d+$/; Integer(value)
            else
                raise ArgumentError, "Invalid recurse value %s" % value.inspect
            end
        end
    end

    newparam(:rmdirs, :boolean => true) do
        desc "Tidy directories in addition to files; that is, remove
            directories whose age is older than the specified criteria.
            This will only remove empty directories, so all contained
            files must also be tidied before a directory gets removed."

        newvalues :true, :false
    end

    # Erase PFile's validate method
    validate do
    end

    def self.instances
        []
    end

    @depthfirst = true

    def initialize(hash)
        super

        # only allow backing up into filebuckets
        unless self[:backup].is_a? Puppet::Network::Client.dipper
            self[:backup] = false
        end
    end

    # Make a file resource to remove a given file.
    def mkfile(path)
        # Force deletion, so directories actually get deleted.
        Puppet::Type.type(:file).new :path => path, :backup => self[:backup], :ensure => :absent, :force => true
    end

    def retrieve
        # Our ensure property knows how to retrieve everything for us.
        if obj = @parameters[:ensure]
            return obj.retrieve
        else
            return {}
        end
    end

    # Hack things a bit so we only ever check the ensure property.
    def properties
        []
    end

    def eval_generate
        []
    end

    def generate
        return [] unless stat(self[:path])

        if self[:recurse]
            files = Puppet::FileServing::Fileset.new(self[:path], :recurse => self[:recurse]).files.collect do |f|
                f == "." ? self[:path] : File.join(self[:path], f)
            end
        else
            files = [self[:path]]
        end
        result = files.find_all { |path| tidy?(path) }.collect { |path| mkfile(path) }.each { |file| notice "Tidying %s" % file.ref }.sort { |a,b| b[:path] <=> a[:path] }

        # No need to worry about relationships if we don't have rmdirs; there won't be
        # any directories.
        return result unless rmdirs?

        # Now make sure that all directories require the files they contain, if all are available,
        # so that a directory is emptied before we try to remove it.
        files_by_name = result.inject({}) { |hash, file| hash[file[:path]] = file; hash }

        files_by_name.keys.sort { |a,b| b <=> b }.each do |path|
            dir = File.dirname(path)
            next unless resource = files_by_name[dir]
            if resource[:require]
                resource[:require] << Puppet::Resource::Reference.new(:file, path)
            else
                resource[:require] = [Puppet::Resource::Reference.new(:file, path)]
            end
        end

        return result
    end

    # Does a given path match our glob patterns, if any?  Return true
    # if no patterns have been provided.
    def matches?(path)
        return true unless self[:matches]

        basename = File.basename(path)
        flags = File::FNM_DOTMATCH | File::FNM_PATHNAME
        if self[:matches].find {|pattern| File.fnmatch(pattern, basename, flags) }
            return true
        else
            debug "No specified patterns match %s, not tidying" % path
            return false
        end
    end

    # Should we remove the specified file?
    def tidy?(path)
        return false unless stat = self.stat(path)

        return false if stat.ftype == "directory" and ! rmdirs?

        # The 'matches' parameter isn't OR'ed with the other tests --
        # it's just used to reduce the list of files we can match.
        return false if param = parameter(:matches) and ! param.tidy?(path, stat)

        tested = false
        [:age, :size].each do |name|
            next unless param = parameter(name)
            tested = true
            return true if param.tidy?(path, stat)
        end

        # If they don't specify either, then the file should always be removed.
        return true unless tested
        return false
    end

    def stat(path)
        begin
            File.lstat(path)
        rescue Errno::ENOENT => error
            info "File does not exist"
            return nil
        rescue Errno::EACCES => error
            warning "Could not stat; permission denied"
            return nil
        end
    end
end
