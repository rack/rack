require 'rubygems'
project = 'rack'
gemspec = File.expand_path("#{project}.gemspec", Dir.pwd)
eval(File.read(gemspec)).development_dependencies.each do |dep|
  gem dep.name, dep.requirement.to_s
end