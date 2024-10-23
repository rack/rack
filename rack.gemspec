# frozen_string_literal: true

require_relative 'lib/rack/version'

Gem::Specification.new do |s|
  s.name = "rack"
  s.version = Rack::VERSION
  s.platform = Gem::Platform::RUBY
  s.summary = "A modular Ruby webserver interface."
  s.license = "MIT"

  s.description = <<~EOF
    Rack provides a minimal, modular and adaptable interface for developing
    web applications in Ruby. By wrapping HTTP requests and responses in
    the simplest way possible, it unifies and distills the API for web
    servers, web frameworks, and software in between (the so-called
    middleware) into a single method call.
  EOF

  s.files = Dir['lib/**/*'] + %w(MIT-LICENSE README.md SPEC.rdoc)
  s.extra_rdoc_files = ['README.md', 'CHANGELOG.md', 'CONTRIBUTING.md']

  s.author = 'Leah Neukirchen'
  s.email = 'leah@vuxu.org'

  s.homepage = 'https://github.com/rack/rack'

  s.required_ruby_version = '>= 2.4.0'

  s.metadata = {
    "bug_tracker_uri" => "https://github.com/rack/rack/issues",
    "changelog_uri" => "https://github.com/rack/rack/blob/main/CHANGELOG.md",
    "documentation_uri" => "https://rubydoc.info/github/rack/rack",
    "source_code_uri"   => "https://github.com/rack/rack",
    "rubygems_mfa_required" => "true"
  }

  s.add_development_dependency 'minitest', "~> 5.0"
  s.add_development_dependency 'minitest-global_expectations'

  s.add_development_dependency 'bundler'
  s.add_development_dependency 'rake'
end
