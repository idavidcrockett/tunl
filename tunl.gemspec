Gem::Specification.new do |s|
  s.name = %q{tunl}
  s.version = "0.0.1"
  s.authors = ["David Crockett"]
  s.date = %q{2009-09-30}
  s.description = %q{EC2 Proxy Service}
  s.email = %q{idavidcrockett@gmail.com}
	s.executables = ['tunl']
  s.files = Dir['lib/**/*.rb'] + Dir['bin/*']
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.1}
  s.summary = %q{EC2 Proxy Service}
end