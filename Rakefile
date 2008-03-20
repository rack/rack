# Rakefile for Rack.  -*-ruby-*-
require 'rake/rdoctask'
require 'rake/testtask'


desc "Run all the tests"
task :default => [:test]

desc "Do predistribution stuff"
task :predist => [:chmod, :changelog, :rdoc]


desc "Make an archive as .tar.gz"
task :dist => :fulltest do
  sh "export DARCS_REPO=#{File.expand_path "."}; " +
     "darcs dist -d rack-#{get_darcs_tree_version}"
end

# Helper to retrieve the "revision number" of the darcs tree.
def get_darcs_tree_version
  unless File.directory? "_darcs"
    $: << "lib"
    require 'rack'
    return Rack.version
  end

  changes = `darcs changes`
  count = 0
  tag = "0.0"

  changes.split("\n\n").each { |change|
    head, title, desc = change.split("\n", 3)

    if title =~ /^  \*/
      # Normal change.
      count += 1
    elsif title =~ /tagged (.*)/
      # Tag.  We look for these.
      tag = $1
      break
    else
      warn "Unparsable change: #{change}"
    end
  }

  tag + "." + count.to_s
end

def manifest
  `darcs query manifest`.split("\n").map { |f| f.gsub(/\A\.\//, '') }
end


desc "Make binaries executable"
task :chmod do
  Dir["bin/*"].each { |binary| File.chmod(0775, binary) }
  Dir["test/cgi/test*"].each { |binary| File.chmod(0775, binary) }
end

desc "Generate a ChangeLog"
task :changelog do
  sh "darcs changes --repo=#{ENV["DARCS_REPO"] || "."} >ChangeLog"
end


desc "Generate RDox"
task "RDOX" do
  sh "specrb -Ilib:test -a --rdox >RDOX"
end

desc "Generate Rack Specification"
task "SPEC" do
  File.open("SPEC", "wb") { |file|
    IO.foreach("lib/rack/lint.rb") { |line|
      if line =~ /## (.*)/
        file.puts $1
      end
    }
  }
end

desc "Run all the fast tests"
task :test do
  sh "specrb -Ilib:test -w #{ENV['TEST'] || '-a'} #{ENV['TESTOPTS'] || '-t "^(?!Rack::Handler|Rack::Adapter|Rack::Session::Memcache)"'}"
end

desc "Run all the tests"
task :fulltest => [:chmod] do
  sh "specrb -Ilib:test -w #{ENV['TEST'] || '-a'} #{ENV['TESTOPTS']}"
end

begin
  require 'rubygems'

  require 'rake'
  require 'rake/clean'
  require 'rake/packagetask'
  require 'rake/gempackagetask'
  require 'fileutils'
rescue LoadError
  # Too bad.
else
  spec = Gem::Specification.new do |s|
    s.name            = "rack"
    s.version         = get_darcs_tree_version
    s.platform        = Gem::Platform::RUBY
    s.summary         = "a modular Ruby webserver interface"

    s.description = <<-EOF
Rack provides minimal, modular and adaptable interface for developing
web applications in Ruby.  By wrapping HTTP requests and responses in
the simplest way possible, it unifies and distills the API for web
servers, web frameworks, and software in between (the so-called
middleware) into a single method call.

Also see http://rack.rubyforge.org.
    EOF

    s.files           = manifest + %w(SPEC RDOX)
    s.bindir          = 'bin'
    s.executables     << 'rackup'
    s.require_path    = 'lib'
    s.has_rdoc        = true
    s.extra_rdoc_files = ['README', 'SPEC', 'RDOX', 'KNOWN-ISSUES']
    s.test_files      = Dir['test/{test,spec}_*.rb']

    s.author          = 'Christian Neukirchen'
    s.email           = 'chneukirchen@gmail.com'
    s.homepage        = 'http://rack.rubyforge.org'
    s.rubyforge_project = 'rack'
  end

  Rake::GemPackageTask.new(spec) do |p|
    p.gem_spec = spec
    p.need_tar = false
    p.need_zip = false
  end
end

desc "Generate RDoc documentation"
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.options << '--line-numbers' << '--inline-source' <<
    '--main' << 'README' <<
    '--title' << 'Rack Documentation' <<
    '--charset' << 'utf-8'
  rdoc.rdoc_dir = "doc"
  rdoc.rdoc_files.include 'README'
  rdoc.rdoc_files.include 'KNOWN-ISSUES'
  rdoc.rdoc_files.include 'SPEC'
  rdoc.rdoc_files.include 'RDOX'
  rdoc.rdoc_files.include('lib/rack.rb')
  rdoc.rdoc_files.include('lib/rack/*.rb')
  rdoc.rdoc_files.include('lib/rack/*/*.rb')
end
task :rdoc => ["SPEC", "RDOX"]

task :pushsite => [:rdoc] do
  sh "rsync -avz doc/ chneukirchen@rack.rubyforge.org:/var/www/gforge-projects/rack/doc/"
  sh "rsync -avz site/ chneukirchen@rack.rubyforge.org:/var/www/gforge-projects/rack/"
end

begin
  require 'rcov/rcovtask'

  Rcov::RcovTask.new do |t|
    t.test_files = FileList['test/{spec,test}_*.rb']
    t.verbose = true     # uncomment to see the executed command
    t.rcov_opts = ["--text-report",
                   "-Ilib:test",
                   "--include-file", "^lib,^test",
                   "--exclude-only", "^/usr,^/home/.*/src,active_"]
  end
rescue LoadError
end
