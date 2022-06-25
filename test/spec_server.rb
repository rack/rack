# frozen_string_literal: true

require_relative 'helper'
require 'tempfile'
require 'socket'
require 'webrick'
require 'open-uri'
require 'net/http'
require 'net/https'

module Minitest::Spec::DSL
  alias :should :it
end

describe Rack::Server do
  SPEC_ARGV = []

  before { SPEC_ARGV[0..-1] = [] }

  def app
    lambda { |env| [200, { 'Content-Type' => 'text/plain' }, ['success']] }
  end

  def with_stderr
    old, $stderr = $stderr, StringIO.new
    yield $stderr
  ensure
    $stderr = old
  end

  it "overrides :config if :app is passed in" do
    server = Rack::Server.new(app: "FOO")
    server.app.must_equal "FOO"
  end

  it "prefer to use :builder when it is passed in" do
    server = Rack::Server.new(builder: "run lambda { |env| [200, {'Content-Type' => 'text/plain'}, ['success']] }")
    server.app.class.must_equal Proc
    Rack::MockRequest.new(server.app).get("/").body.to_s.must_equal 'success'
  end

  it "allow subclasses to override middleware" do
    server = Class.new(Rack::Server).class_eval { def middleware; Hash.new [] end; self }
    server.middleware['deployment'].wont_equal []
    server.new(app: 'foo').middleware['deployment'].must_equal []
  end

  it "allow subclasses to override default middleware" do
    server = Class.new(Rack::Server).instance_eval { def default_middleware_by_environment; Hash.new [] end; self }
    server.middleware['deployment'].must_equal []
    server.new(app: 'foo').middleware['deployment'].must_equal []
  end

  it "only provide default middleware for development and deployment environments" do
    Rack::Server.default_middleware_by_environment.keys.sort.must_equal %w(deployment development)
  end

  it "always return an empty array for unknown environments" do
    server = Rack::Server.new(app: 'foo')
    server.middleware['production'].must_equal []
  end

  it "not include Rack::Lint in deployment environment" do
    server = Rack::Server.new(app: 'foo')
    server.middleware['deployment'].flatten.wont_include Rack::Lint
  end

  it "not include Rack::ShowExceptions in deployment environment" do
    server = Rack::Server.new(app: 'foo')
    server.middleware['deployment'].flatten.wont_include Rack::ShowExceptions
  end

  it "include Rack::TempfileReaper in deployment environment" do
    server = Rack::Server.new(app: 'foo')
    server.middleware['deployment'].flatten.must_include Rack::TempfileReaper
  end

  it "support CGI" do
    begin
      o, ENV["REQUEST_METHOD"] = ENV["REQUEST_METHOD"], 'foo'
      server = Rack::Server.new(app: 'foo')
      server.server.name =~ /CGI/
      Rack::Server.logging_middleware.call(server).must_be_nil
    ensure
      ENV['REQUEST_METHOD'] = o
    end
  end

  it "be quiet if said so" do
    server = Rack::Server.new(app: "FOO", quiet: true)
    Rack::Server.logging_middleware.call(server).must_be_nil
  end

  it "use a full path to the pidfile" do
    # avoids issues with daemonize chdir
    opts = Rack::Server.new.send(:parse_options, %w[--pid testing.pid])
    opts[:pid].must_equal ::File.expand_path('testing.pid')
  end

  it "get options from ARGV" do
    SPEC_ARGV[0..-1] = ['--debug', '-sthin', '--env', 'production', '-w', '-q', '-o', '127.0.0.1', '-O', 'NAME=VALUE', '-ONAME2', '-D']
    server = Rack::Server.new
    server.options[:debug].must_equal true
    server.options[:server].must_equal 'thin'
    server.options[:environment].must_equal 'production'
    server.options[:warn].must_equal true
    server.options[:quiet].must_equal true
    server.options[:Host].must_equal '127.0.0.1'
    server.options[:NAME].must_equal 'VALUE'
    server.options[:NAME2].must_equal true
    server.options[:daemonize].must_equal true
  end

  it "only override non-passed options from parsed .ru file" do
    builder_file = File.join(File.dirname(__FILE__), 'builder', 'options.ru')
    SPEC_ARGV[0..-1] = ['--debug', '-sthin', '--env', 'production', builder_file]
    server = Rack::Server.new
    server.app # force .ru file to be parsed

    server.options[:debug].must_equal true
    server.options[:server].must_equal 'thin'
    server.options[:environment].must_equal 'production'
    server.options[:Port].must_equal '2929'
  end

  def test_options_server(*args)
    SPEC_ARGV[0..-1] = args
    output = String.new
    server = Class.new(Rack::Server) do
      define_method(:opt_parser) do
        Class.new(Rack::Server::Options) do
          define_method(:puts) do |*args|
            output << args.join("\n") << "\n"
          end
          alias warn puts
          alias abort puts
          define_method(:exit) do
            output << "exited"
          end
        end.new
      end
    end.new
    output
  end

  it "support -h option to get help" do
    test_options_server('-scgi', '-h').must_match(/\AUsage: rackup.*Ruby options:.*Rack options.*Profiling options.*Common options.*exited\z/m)
  end

  it "support -h option to get handler-specific help" do
    cgi = Rack::Handler.get('cgi')
    begin
      def cgi.valid_options; { "FOO=BAR" => "BAZ" } end
      test_options_server('-scgi', '-h').must_match(/\AUsage: rackup.*Ruby options:.*Rack options.*Profiling options.*Common options.*Server-specific options for Rack::Handler::CGI.*-O +FOO=BAR +BAZ.*exited\z/m)
    ensure
      cgi.singleton_class.send(:remove_method, :valid_options)
    end
  end

  it "support -h option to display warning for invalid handler" do
    test_options_server('-sbanana', '-h').must_match(/\AUsage: rackup.*Ruby options:.*Rack options.*Profiling options.*Common options.*Warning: Could not find handler specified \(banana\) to determine handler-specific options.*exited\z/m)
  end

  it "support -v option to get version" do
    test_options_server('-v').must_match(/\ARack \d\.\d \(Release: \d+\.\d+\.\d+(\.\d+)?\)\nexited\z/)
  end

  it "warn for invalid --profile-mode option" do
    test_options_server('--profile-mode', 'foo').must_match(/\Ainvalid option: --profile-mode unknown profile mode: foo.*Usage: rackup/m)
  end

  it "warn for invalid options" do
    test_options_server('--banana').must_match(/\Ainvalid option: --banana.*Usage: rackup/m)
  end

  it "support -b option to specify inline rackup config" do
    SPEC_ARGV[0..-1] = ['-scgi', '-E', 'development', '-b', 'use Rack::ContentLength; run ->(env){[200, {}, []]}']
    server = Rack::Server.new
    def (server.server).run(app, **) app end
    s, h, b = server.start.call('rack.errors' => StringIO.new)
    s.must_equal 500
    h['Content-Type'].must_equal 'text/plain'
    b.join.must_include 'Rack::Lint::LintError'
  end

  it "support -e option to evaluate ruby code" do
    SPEC_ARGV[0..-1] = ['-scgi', '-e', 'Object::XYZ = 2']
    begin
      server = Rack::Server.new
      Object::XYZ.must_equal 2
    ensure
      Object.send(:remove_const, :XYZ)
    end
  end

  it "abort if config file does not exist" do
    SPEC_ARGV[0..-1] = ['-scgi']
    server = Rack::Server.new
    def server.abort(s) throw :abort, s end
    message = catch(:abort) do
      server.start
    end
    message.must_match(/\Aconfiguration .*config\.ru not found/)
  end

  it "support -I option to change the load path and -r to require" do
    SPEC_ARGV[0..-1] = ['-scgi', '-Ifoo/bar', '-Itest/load', '-rrack-test-a', '-rrack-test-b']
    begin
      server = Rack::Server.new
      def (server.server).run(*) end
      def server.handle_profiling(*) end
      def server.app(*) end
      server.start
      $LOAD_PATH.must_include('foo/bar')
      $LOAD_PATH.must_include('test/load')
      $LOADED_FEATURES.must_include(File.join(Dir.pwd, "test/load/rack-test-a.rb"))
      $LOADED_FEATURES.must_include(File.join(Dir.pwd, "test/load/rack-test-b.rb"))
    ensure
      $LOAD_PATH.delete('foo/bar')
      $LOAD_PATH.delete('test/load')
      $LOADED_FEATURES.delete(File.join(Dir.pwd, "test/load/rack-test-a.rb"))
      $LOADED_FEATURES.delete(File.join(Dir.pwd, "test/load/rack-test-b.rb"))
    end
  end

  it "support -w option to warn and -d option to debug" do
    SPEC_ARGV[0..-1] = ['-scgi', '-d', '-w']
    warn = $-w
    debug = $DEBUG
    begin
      server = Rack::Server.new
      def (server.server).run(*) end
      def server.handle_profiling(*) end
      def server.app(*) end
      def server.p(*) end
      def server.pp(*) end
      def server.require(*) end
      server.start
      $-w.must_equal true
      $DEBUG.must_equal true
    ensure
      $-w = warn
      $DEBUG = debug
    end
  end

  if RUBY_ENGINE == "ruby"
    it "support --heap option for heap profiling" do
      begin
        require 'objspace'
      rescue LoadError
      else
        t = Tempfile.new
        begin
          SPEC_ARGV[0..-1] = ['-scgi', '--heap', t.path, '-E', 'production', '-b', 'run ->(env){[200, {}, []]}']
          server = Rack::Server.new
          def (server.server).run(*) end
          def server.exit; throw :exit end
          catch :exit do
            server.start
          end
          File.file?(t.path).must_equal true
        ensure
          File.delete t.path
        end
      end
    end

    it "support --profile-mode option for stackprof profiling" do
      begin
        require 'stackprof'
      rescue LoadError
      else
        t = Tempfile.new
        begin
          SPEC_ARGV[0..-1] = ['-scgi', '--profile', t.path, '--profile-mode', 'cpu', '-E', 'production', '-b', 'run ->(env){[200, {}, []]}']
          server = Rack::Server.new
          def (server.server).run(*) end
          def server.puts(*) end
          def server.exit; throw :exit end
          catch :exit do
            server.start
          end
          File.file?(t.path).must_equal true
        ensure
          File.delete t.path
        end
      end
    end

    it "support --profile-mode option for stackprof profiling without --profile option" do
      begin
        require 'stackprof'
      rescue LoadError
      else
        begin
          SPEC_ARGV[0..-1] = ['-scgi', '--profile-mode', 'cpu', '-E', 'production', '-b', 'run ->(env){[200, {}, []]}']
          server = Rack::Server.new
          def (server.server).run(*) end
          filename = nil
          server.define_singleton_method(:make_profile_name) do |fname, &block|
            super(fname) do |fn|
              filename = fn
              block.call(filename)
            end
          end
          def server.puts(*) end
          def server.exit; throw :exit end
          catch :exit do
            server.start
          end
          File.file?(filename).must_equal true
        ensure
          File.delete filename
        end
      end
    end
  end

  it "support exit for INT signal when server does not respond to shutdown" do
    SPEC_ARGV[0..-1] = ['-scgi']
    server = Rack::Server.new
    def (server.server).run(*) end
    def server.handle_profiling(*) end
    def server.app(*) end
    exited = false
    server.define_singleton_method(:exit) do
      exited = true
    end
    server.start
    exited.must_equal false
    Process.kill(:INT, $$)
    sleep 1 unless RUBY_ENGINE == 'ruby'
    exited.must_equal true
  end

  it "support support Server.start for starting" do
    SPEC_ARGV[0..-1] = ['-scgi']
    c = Class.new(Rack::Server) do
      def start(*) [self.class, :started] end
    end
    c.start.must_equal [c, :started]
  end


  it "run a server" do
    pidfile = Tempfile.open('pidfile') { |f| break f }
    FileUtils.rm pidfile.path
    server = Rack::Server.new(
      app: app,
      environment: 'none',
      pid: pidfile.path,
      Port: TCPServer.open('127.0.0.1', 0){|s| s.addr[1] },
      Host: '127.0.0.1',
      Logger: WEBrick::Log.new(nil, WEBrick::BasicLog::WARN),
      AccessLog: [],
      daemonize: false,
      server: 'webrick'
    )
    t = Thread.new { server.start { |s| Thread.current[:server] = s } }
    t.join(0.01) until t[:server] && t[:server].status != :Stop
    body = if URI.respond_to?(:open)
             URI.open("http://127.0.0.1:#{server.options[:Port]}/") { |f| f.read }
           else
             open("http://127.0.0.1:#{server.options[:Port]}/") { |f| f.read }
           end
    body.must_equal 'success'

    Process.kill(:INT, $$)
    t.join
    open(pidfile.path) { |f| f.read.must_equal $$.to_s }
  end

  it "run a secure server" do
    pidfile = Tempfile.open('pidfile') { |f| break f }
    FileUtils.rm pidfile.path
    server = Rack::Server.new(
      app: app,
      environment: 'none',
      pid: pidfile.path,
      Port: TCPServer.open('127.0.0.1', 0){|s| s.addr[1] },
      Host: '127.0.0.1',
      Logger: WEBrick::Log.new(nil, WEBrick::BasicLog::WARN),
      AccessLog: [],
      daemonize: false,
      server: 'webrick',
      SSLEnable: true,
      SSLCertName: [['CN', 'nobody'], ['DC', 'example']]
    )
    t = Thread.new { server.start { |s| Thread.current[:server] = s } }
    t.join(0.01) until t[:server] && t[:server].status != :Stop

    uri = URI.parse("https://127.0.0.1:#{server.options[:Port]}/")

    Net::HTTP.start("127.0.0.1", uri.port, use_ssl: true,
      verify_mode: OpenSSL::SSL::VERIFY_NONE) do |http|

      request = Net::HTTP::Get.new uri

      body = http.request(request).body
      body.must_equal 'success'
    end

    Process.kill(:INT, $$)
    t.join
    open(pidfile.path) { |f| f.read.must_equal $$.to_s }
  end if RUBY_VERSION >= "2.6"

  it "check pid file presence and running process" do
    pidfile = Tempfile.open('pidfile') { |f| f.write($$); break f }.path
    server = Rack::Server.new(pid: pidfile)
    server.send(:pidfile_process_status).must_equal :running
  end

  it "check pid file presence and dead process" do
    dead_pid = `echo $$`.to_i
    pidfile = Tempfile.open('pidfile') { |f| f.write(dead_pid); break f }.path
    server = Rack::Server.new(pid: pidfile)
    server.send(:pidfile_process_status).must_equal :dead
  end

  it "check pid file presence and exited process" do
    pidfile = Tempfile.open('pidfile') { |f| break f }.path
    ::File.delete(pidfile)
    server = Rack::Server.new(pid: pidfile)
    server.send(:pidfile_process_status).must_equal :exited
  end

  it "check pid file presence and not owned process" do
    owns_pid_1 = (Process.kill(0, 1) rescue nil) == 1
    skip "cannot test if pid 1 owner matches current process (eg. docker/lxc)" if owns_pid_1
    pidfile = Tempfile.open('pidfile') { |f| f.write(1); break f }.path
    server = Rack::Server.new(pid: pidfile)
    server.send(:pidfile_process_status).must_equal :not_owned
  end

  it "rewrite pid file when it does not reference a running process" do
    pidfile = Tempfile.open('pidfile') { |f| break f }.path
    server = Rack::Server.new(pid: pidfile)
    ::File.open(pidfile, 'w') { }
    server.send(:write_pid)
    ::File.read(pidfile).to_i.must_equal $$
  end

  it "not write pid file when it references a running process" do
    pidfile = Tempfile.open('pidfile') { |f| break f }.path
    ::File.delete(pidfile)
    server = Rack::Server.new(pid: pidfile)
    ::File.open(pidfile, 'w') { |f| f.write(1) }
    with_stderr do |err|
      lambda { server.send(:write_pid) }.must_raise SystemExit
      err.rewind
      output = err.read
      output.must_match(/already running/)
      output.must_include pidfile
    end
  end

  it "inform the user about existing pidfiles with running processes" do
    pidfile = Tempfile.open('pidfile') { |f| f.write(1); break f }.path
    server = Rack::Server.new(pid: pidfile)
    with_stderr do |err|
      lambda { server.start }.must_raise SystemExit
      err.rewind
      output = err.read
      output.must_match(/already running/)
      output.must_include pidfile
    end
  end

end
