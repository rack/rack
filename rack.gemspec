# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name = "rack"
  s.version = File.read('lib/rack.rb')[/RELEASE += +([\"\'])([\d][\w\.]+)\1/, 2]
  s.platform        = Gem::Platform::RUBY
  s.summary         = "a modular Ruby webserver interface"
  s.license         = "MIT"

  s.description = <<-EOF
Rack provides a minimal, modular and adaptable interface for developing
web applications in Ruby.  By wrapping HTTP requests and responses in
the simplest way possible, it unifies and distills the API for web
servers, web frameworks, and software in between (the so-called
middleware) into a single method call.

Also see https://rack.github.io/.
EOF

  s.files           = Dir['{bin/*,contrib/*,example/*,lib/**/*}'] +
                        %w(MIT-LICENSE rack.gemspec Rakefile README.rdoc SPEC)
  s.bindir          = 'bin'
  s.executables << 'rackup'
  s.require_path = 'lib'
  s.extra_rdoc_files = ['README.rdoc', 'CHANGELOG.md']

  s.author          = 'Leah Neukirchen'
  s.email           = 'leah@vuxu.org'
  s.homepage        = 'https://rack.github.io/'
  s.required_ruby_version = '>= 2.2.2'
  s.metadata              = {
    "bug_tracker_uri"   => "https://github.com/rack/rack/issues",
    "changelog_uri"     => "https://github.com/rack/rack/blob/master/CHANGELOG.md",
    "documentation_uri" => "https://rubydoc.info/github/rack/rack",
    "homepage_uri"      => "https://rack.github.io",
    "mailing_list_uri"  => "https://groups.google.com/forum/#!forum/rack-devel",
    "source_code_uri"   => "https://github.com/rack/rack"
  }

  s.add_development_dependency 'minitest', "~> 5.0"
  s.add_development_dependency 'minitest-sprint'
  s.add_development_dependency 'minitest-global_expectations'
  s.add_development_dependency 'rake'
end
