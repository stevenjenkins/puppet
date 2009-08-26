# This set of tasks helps automate the workflow as described on
# http://reductivelabs.com/trac/puppet/wiki/Development/DevelopmentLifecycle

# This should be changed as new versions get released
@next_release = "0.26.x"

def find_start(start)
# This is a case statement, as we might want to map certain
# git tags to starting points that are not currently in git.
	case start
		when @next_release: return "master"
		else return start
	end
end

desc "Do git setup to start work on a feature"
task :start_feature, [:feature,:branch] do |t, args|
	args.with_defaults(:branch => @next_release)
	start_at = find_start(args.branch)
	command = "git checkout -b feature/#{start_at}/#{args.feature} #{start_at}"
	%x{#{command}}
	if $? != 0
		raise <<EOS
Was not able to create branch for #{args.feature} on branch #{args.branch}, starting at #{start_at}: error code was: #{$?}
Git command used was: #{command}

The most common error is to specify a non-existent starting point.
EOS
	end
end

desc "Do git setup to start work on a Redmine ticket"
task :start_ticket, [:ticket, :branch] do |t, args|
	args.with_defaults(:branch => @next_release)

	start_at = find_start(args.branch)
	command = "git checkout -b ticket/#{args.branch}/#{args.ticket} #{start_at}"
	%x{#{command}}
	if $? != 0
		raise <<EOS
Was not able to create branch for ticket #{args.ticket} on branch #{args.branch}, starting at #{start_at}: error code was: #{$?}
Git command used was: #{command}

The most common error is to specify a non-existent starting point.
EOS
	end
end

# This isn't very useful by itself, but we might enhance it later, or use it
# in a dependency for a more complex task.
desc "Push out changes"
task :push_changes, [:remote] do |t, arg|
	branch = %x{git branch | grep "^" | awk '{print $2}'}
	%x{git push #{arg.remote} #{branch}}
	raise "Unable to push to #{arg.remote}" if $? != 0
end

desc "Send patch information to the puppet-dev list"
task :mail_patches do
    if Dir.glob("00*.patch").length > 0
        raise "Patches already exist matching '00*.patch'; clean up first"
    end

    unless %x{git status} =~ /On branch (.+)/
        raise "Could not get branch from 'git status'"
    end
    branch = $1

    unless branch =~ %r{^([^\/]+)/([^\/]+)/([^\/]+)$}
        raise "Branch name does not follow <type>/<parent>/<name> model; cannot autodetect parent branch"
    end

    type, parent, name = $1, $2, $3

    # Create all of the patches
    sh "git format-patch -C -M -s -n --subject-prefix='PATCH/puppet' #{parent}..HEAD"

    # And then mail them out.

    # If we've got more than one patch, add --compose
    if Dir.glob("00*.patch").length > 1
        compose = "--compose"
    else
        compose = ""
    end

    # Now send the mail.
    sh "git send-email #{compose} --no-signed-off-by-cc --suppress-from --to puppet-dev@googlegroups.com 00*.patch"

    # Finally, clean up the patches
    sh "rm 00*.patch"
end

