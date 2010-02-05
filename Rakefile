desc 'build and install the gem'
task :install do
	exec 'gem build tunl.gemspec && sudo gem install tunl-0.0.1.gem --no-rdoc --no-ri'
end

desc 'test the gem'
task :test do
	require 'test/tunl.rb'
end