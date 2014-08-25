module Rack

  class Server

    # Start a new rack server (like running rackup). This will parse ARGV and
    # provide standard ARGV rackup options, defaulting to load 'config.ru'.
    #
    # Providing an options hash will prevent ARGV parsing and will not include
    # any default options.
    #
    # This method can be used to very easily launch a CGI application, for
    # example:
    #
    #  Rack::Server.start(
    #    :app => lambda do |e|
    #      [200, {'Content-Type' => 'text/html'}, ['hello world']]
    #    end,
    #    :server => 'cgi'
    #  )
    #
    # Further options available here are documented on Rack::Server#initialize
    def self.start(options = nil)
      new(options).start
    end

    attr_writer :options

    # Options may include:
    # * :app
    #     a rack application to run (overrides :config)
    # * :config
    #     a rackup configuration file path to load (.ru)
    # * :environment
    #     this selects the middleware that will be wrapped around
    #     your application. Default options available are:
    #       - development: CommonLogger, ShowExceptions, and Lint
    #       - deployment: CommonLogger
    #       - none: no extra middleware
    #     note: when the server is a cgi server, CommonLogger is not included.
    # * :server
    #     choose a specific Rack::Handler, e.g. cgi, fcgi, webrick
    # * :daemonize
    #     if true, the server will daemonize itself (fork, detach, etc)
    # * :pid
    #     path to write a pid file after daemonize
    # * :Host
    #     the host address to bind to (used by supporting Rack::Handler)
    # * :Port
    #     the port to bind to (used by supporting Rack::Handler)
    # * :AccessLog
    #     webrick access log options (or supporting Rack::Handler)
    # * :debug
    #     turn on debug output ($DEBUG = true)
    # * :warn
    #     turn on warnings ($-w = true)
    # * :include
    #     add given paths to $LOAD_PATH
    # * :require
    #     require the given libraries
    def initialize(options = nil)
      @options = options
      @app = options[:app] if options && options[:app]
    end

    def options
      @options ||= parse_options(ARGV)
    end

    def default_options
      environment  = ENV['RACK_ENV'] || 'development'
      default_host = environment == 'development' ? 'localhost' : '0.0.0.0'

      {
        :environment => environment,
        :pid         => nil,
        :Port        => 9292,
        :Host        => default_host,
        :AccessLog   => [],
        :config      => "config.ru"
      }
    end

    def app
      @app ||= options[:builder] ? build_app_from_string : build_app_and_options_from_config
    end

    class << self
      def logging_middleware
        lambda { |server|
          server.server.name =~ /CGI/ || server.options[:quiet] ? nil : [Rack::CommonLogger, $stderr]
        }
      end

      def default_middleware_by_environment
        m = Hash.new {|h,k| h[k] = []}
        m["deployment"] = [
          [Rack::ContentLength],
          [Rack::Chunked],
          logging_middleware,
          [Rack::TempfileReaper]
        ]
        m["development"] = [
          [Rack::ContentLength],
          [Rack::Chunked],
          logging_middleware,
          [Rack::ShowExceptions],
          [Rack::Lint],
          [Rack::TempfileReaper]
        ]

        m
      end

      # Aliased for backwards-compatibility
      alias :middleware :default_middleware_by_environment
    end

    def default_middleware_by_environment
      self.class.default_middleware_by_environment
    end

    # Aliased for backwards-compatibility
    alias :middleware :default_middleware_by_environment

    def start &blk
      if options[:warn]
        $-w = true
      end

      if includes = options[:include]
        $LOAD_PATH.unshift(*includes)
      end

      if library = options[:require]
        require library
      end

      if options[:debug]
        $DEBUG = true
        require 'pp'
        p options[:server]
        pp wrapped_app
        pp app
      end

      check_pid! if options[:pid]

      # Touch the wrapped app, so that the config.ru is loaded before
      # daemonization (i.e. before chdir, etc).
      wrapped_app

      daemonize_app if options[:daemonize]

      write_pid if options[:pid]

      trap(:INT) do
        if server.respond_to?(:shutdown)
          server.shutdown
        else
          exit
        end
      end

      server.run wrapped_app, options, &blk
    end

    def server
      @_server ||= Rack::Handler.get(options[:server]) || Rack::Handler.default(options)
    end

    private
      def build_app_and_options_from_config
        if !::File.exist? options[:config]
          abort "configuration #{options[:config]} not found"
        end

        app, options = Rack::Builder.parse_file(self.options[:config], opt_parser)
        self.options.merge! options
        app
      end

      def build_app_from_string
        Rack::Builder.new_from_string(self.options[:builder])
      end

      def parse_options(args)
        options = default_options

        # Don't evaluate CGI ISINDEX parameters.
        # http://www.meb.uni-bonn.de/docs/cgi/cl.html
        args.clear if ENV.include?("REQUEST_METHOD")

        options.merge! opt_parser.parse!(args)
        options[:config] = ::File.expand_path(options[:config])
        ENV["RACK_ENV"] = options[:environment]
        options
      end

      def opt_parser
        Rack::Options
      end

      def build_app(app)
        middlewares = default_middleware_by_environment[options[:environment]]
        middlewares.reverse_each do |middleware|
          middleware = middleware.call(self) if middleware.respond_to?(:call)
          next unless middleware
          klass, *args = middleware
          app = klass.new(app, *args)
        end
        app
      end

      def wrapped_app
        @wrapped_app ||= build_app app
      end

      def daemonize_app
        if RUBY_VERSION < "1.9"
          exit if fork
          Process.setsid
          exit if fork
          Dir.chdir "/"
          STDIN.reopen "/dev/null"
          STDOUT.reopen "/dev/null", "a"
          STDERR.reopen "/dev/null", "a"
        else
          Process.daemon
        end
      end

      def write_pid
        ::File.open(options[:pid], ::File::CREAT | ::File::EXCL | ::File::WRONLY ){ |f| f.write("#{Process.pid}") }
        at_exit { ::File.delete(options[:pid]) if ::File.exist?(options[:pid]) }
      rescue Errno::EEXIST
        check_pid!
        retry
      end

      def check_pid!
        case pidfile_process_status
        when :running, :not_owned
          $stderr.puts "A server is already running. Check #{options[:pid]}."
          exit(1)
        when :dead
          ::File.delete(options[:pid])
        end
      end

      def pidfile_process_status
        return :exited unless ::File.exist?(options[:pid])

        pid = ::File.read(options[:pid]).to_i
        return :dead if pid == 0

        Process.kill(0, pid)
        :running
      rescue Errno::ESRCH
        :dead
      rescue Errno::EPERM
        :not_owned
      end

  end

end
