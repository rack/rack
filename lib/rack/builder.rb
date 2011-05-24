module Rack
  # Rack::Builder implements a small DSL to iteratively construct Rack
  # applications.
  #
  # Example:
  #
  #  require 'rack/lobster'
  #  app = Rack::Builder.new do
  #    use Rack::CommonLogger
  #    use Rack::ShowExceptions
  #    map "/lobster" do
  #      use Rack::Lint
  #      run Rack::Lobster.new
  #    end
  #  end
  #
  #  run app
  #
  # Or
  #
  #  app = Rack::Builder.app do
  #    use Rack::CommonLogger
  #    lambda { |env| [200, {'Content-Type' => 'text/plain'}, 'OK'] }
  #  end
  #
  #  run app
  #
  # +use+ adds a middleware to the stack, +run+ dispatches to an application.
  # You can use +map+ to construct a Rack::URLMap in a convenient way.

  class Builder
    def self.parse_file(config, opts = Server::Options.new)
      options = {}
      if config =~ /\.ru$/
        cfgfile = ::File.read(config)
        if cfgfile[/^#\\(.*)/] && opts
          options = opts.parse! $1.split(/\s+/)
        end
        cfgfile.sub!(/^__END__\n.*/, '')
        app = eval "Rack::Builder.new {\n" + cfgfile + "\n}.to_app",
          TOPLEVEL_BINDING, config
      else
        require config
        app = Object.const_get(::File.basename(config, '.rb').capitalize)
      end
      return app, options
    end

    def initialize(&block)
      @ins = []
      instance_eval(&block) if block_given?
    end

    def self.app(&block)
      self.new(&block).to_app
    end

    # Specifies a middleware to use in a stack.
    #
    #   class Middleware
    #     def initialize(app)
    #       @app = app
    #     end
    #
    #     def call(env)
    #       env["rack.some_header"] = "setting an example"
    #       @app.call(env)
    #     end
    #   end
    #
    #   use Middleware
    #   run lambda { |env| [200, { "Content-Type => "text/plain" }, ["OK"]] }
    #
    # All requests through to this application will first be processed by the middleware class.
    # The +call+ method in this example sets an additional environment key which then can be
    # referenced in the application if required.
    def use(middleware, *args, &block)
      @ins << lambda { |app| middleware.new(app, *args, &block) }
    end

    # Takes an argument that is an object that responds to #call and returns a Rack response.
    # The simplest form of this is a lambda object:
    #
    #   run lambda { |env| [200, { "Content-Type" => "text/plain" }, ["OK"]] }
    #
    # However this could also be a class:
    #
    #   class Heartbeat
    #     def self.call(env)
    #      [200, { "Content-Type" => "text/plain" }, ["OK"]]
    #    end
    #   end
    #
    #   run Heartbeat
    def run(app)
      @ins << app #lambda { |nothing| app }
    end

    # Creates a route within the application.
    #
    #   Rack::Builder.app do
    #     map '/' do
    #       run Heartbeat
    #     end
    #   end
    #
    # The +use+ method can also be used here to specify middleware to run under a specific path:
    #
    #   Rack::Builder.app do
    #     map '/' do
    #       use Middleware
    #       run Heartbeat
    #     end
    #   end
    #
    # This example includes a piece of middleware which will run before requests hit +Heartbeat+.
    #
    def map(path, &block)
      if @ins.last.kind_of? Hash
        @ins.last[path] = self.class.new(&block).to_app
      else
        @ins << {}
        map(path, &block)
      end
    end

    def to_app
      @ins[-1] = Rack::URLMap.new(@ins.last)  if Hash === @ins.last
      inner_app = @ins.last
      @ins[0...-1].reverse.inject(inner_app) { |a, e| e.call(a) }
    end

    def call(env)
      to_app.call(env)
    end
  end
end
