module Puppet::Util::Backups

        # Deal with backups.
        def handlebackup(file = nil)
            # let the path be specified
            file ||= self[:path]
            # if they specifically don't want a backup, then just say
            # we're good
            unless FileTest.exists?(file)
                return true
            end

            unless self[:backup]
                return true
            end

            backup = self.bucket || self[:backup]
            case File.stat(file).ftype
            when "directory"
                # we don't need to backup directories when recurse is on
		return true if self[:recurse]

		if self.bucket
                    notice "Recursively backing up to filebucket"
                    require 'find'
                    Find.find(self[:path]) do |f|
                        if File.file?(f)
                            sum = backup.backup(f)
                            self.notice "Filebucketed %s to %s with sum %s" %
                                [f, backup.name, sum]
                        end
                    end

                    return true
		elsif self[:backup]
		    handlebackuplocal(file)
                else
                    self.err "Invalid backup type %s" % backup.inspect
                    return false
                end
            when "file"
		if self.bucket
                    sum = backup.backup(file)
                    self.notice "Filebucketed to %s with sum %s" %
                        [backup.name, sum]
                    return true
                elsif self[:backup]
		    handlebackuplocal(file)
                else
                    self.err "Invalid backup type %s" % backup.inspect
                    return false
                end
            when "link"; return true
            else
                self.notice "Cannot backup files of type %s" % File.stat(file).ftype
                return false
            end
        end

private

	def remove_backup(newfile)
            if self.class.name == :file and self[:links] != :follow
                method = :lstat
            else
                method = :stat
            end
            old = File.send(method, newfile).ftype

            if old == "directory"
                raise Puppet::Error,
                    "Will not remove directory backup %s; use a filebucket" %
                    newfile
            end

            info "Removing old backup of type %s" %
                File.send(method, newfile).ftype

            begin
                File.unlink(newfile)
            rescue => detail
                puts detail.backtrace if Puppet[:trace]
                self.err "Could not remove old backup: %s" % detail
                return false
            end
        end

	def handlelocalbackup(file)
            newfile = file + backup
            if FileTest.exists?(newfile)
                remove_backup(newfile)
            end

             begin
             	bfile = file + backup

              	# Ruby 1.8.1 requires the 'preserve' addition, but
              	# later versions do not appear to require it.
		# N.B. cp_r works on both files and directories
              	FileUtils.cp_r(file, bfile, :preserve => true)
              	return true
              rescue => detail
                # since they said they want a backup, let's error out
                # if we couldn't make one
                self.fail "Could not back %s up: %s" %
                    [file, detail.message]
              end
	end

end
