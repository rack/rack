# frozen_string_literal: true

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
  #    run lambda { |env| [200, {'Content-Type' => 'text/plain'}, ['OK']] }
  #  end
  #
  #  run app
  #
  # +use+ adds middleware to the stack, +run+ dispatches to an application.
  # You can use +map+ to construct a Rack::URLMap in a convenient way.

  class Builder

    # https://stackoverflow.com/questions/2223882/whats-the-difference-between-utf-8-and-utf-8-without-bom
    UTF_8_BOM = '\xef\xbb\xbf'

    # Load the given file as a rackup file, treating the
    # contents as if specified inside a Rack::Builder block.
    #
    # Ignores content in the file after +__END__+, so that
    # use of +__END__+ will not result in a syntax error.
    #
    # Example config.ru file:
    #
    #   $ cat config.ru
    #
    #   #\ -p 9393
    #
    #   use Rack::ContentLength
    #   require './app.rb'
    #   run App
    def self.load_file(path, **options)
      config = ::File.read(path)
      config.slice!(/\A#{UTF_8_BOM}/) if config.encoding == Encoding::UTF_8

      if config[/^#\\(.*)/]
        fail "Parsing options from the first comment line is deprecated: #{path}"
      end

      config.sub!(/^__END__\n.*\Z/m, '')

      return new_from_string(config, path, **options)
    end

    # Evaluate the given +builder_script+ string in the context of
    # a Rack::Builder block, returning a Rack application.
    def self.new_from_string(builder_script, file = "(rackup)", **options)
      builder = self.new(**options)

      # Create a top level scope with self as the builder instance:
      binding = TOPLEVEL_BINDING.eval('->(builder){builder.instance_eval{binding}}').call(builder)
      
      eval(builder_script, binding, file)

      return builder.to_app
    end

    # Initialize a new Rack::Builder instance.  +default_app+ specifies the
    # default application if +run+ is not called later.  If a block
    # is given, it is evaluted in the context of the instance.
    def initialize(default_app = nil, **options, &block)
      @use = []
      @map = nil
      @run = default_app
      @warmup = nil
      @freeze_app = false

      @options = options

      instance_eval(&block) if block_given?
    end

    attr :options

    # Whether the application server will invoke the application from multiple threads. Implies {reentrant?}.
    def multithread?
      @options[:multithread]
    end

    # Re-entrancy is a feature of event-driven servers which may perform non-blocking operations. When an operation blocks, that particular request may yield and another request may enter the application stack.
    # @return [Boolean] Whether the application can be invoked multiple times from the same thread.
    def reentrant?
      @options[:reentrant]
    end

    # Create a new Rack::Builder instance and return the Rack application
    # generated from it.
    def self.app(default_app = nil, &block)
      self.new(default_app, &block).to_app
    end

    # Specifies middleware to use in a stack.
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
    #   run lambda { |env| [200, { "Content-Type" => "text/plain" }, ["OK"]] }
    #
    # All requests through to this application will first be processed by the middleware class.
    # The +call+ method in this example sets an additional environment key which then can be
    # referenced in the application if required.
    def use(middleware, *args, &block)
      if @map
        mapping, @map = @map, nil
        @use << proc { |app| generate_map(app, mapping) }
      end
      @use << proc { |app| middleware.new(app, *args, &block) }
    end
    ruby2_keywords(:use) if respond_to?(:ruby2_keywords, true)

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
    #     end
    #   end
    #
    #   run Heartbeat
    def run(app)
      @run = app
    end

    # Takes a lambda or block that is used to warm-up the application. This block is called
    # before the Rack application is returned by to_app.
    #
    #   warmup do |app|
    #     client = Rack::MockRequest.new(app)
    #     client.get('/')
    #   end
    #
    #   use SomeMiddleware
    #   run MyApp
    def warmup(prc = nil, &block)
      @warmup = prc || block
    end

    # Creates a route within the application.  Routes under the mapped path will be sent to
    # the Rack application specified by run inside the block.  Other requests will be sent to the
    # default application specified by run outside the block.
    #
    #   Rack::Builder.app do
    #     map '/heartbeat' do
    #       run Heartbeat
    #     end
    #     run App
    #   end
    #
    # The +use+ method can also be used inside the block to specify middleware to run under a specific path:
    #
    #   Rack::Builder.app do
    #     map '/heartbeat' do
    #       use Middleware
    #       run Heartbeat
    #     end
    #     run App
    #   end
    #
    # This example includes a piece of middleware which will run before +/heartbeat+ requests hit +Heartbeat+.
    #
    # Note that providing a +path+ of +/+ will ignore any default application given in a +run+ statement
    # outside the block.
    def map(path, &block)
      @map ||= {}
      @map[path] = block
    end

    # Freeze the app (set using run) and all middleware instances when building the application
    # in to_app.
    def freeze_app
      @freeze_app = true
    end

    # Return the Rack application generated by this instance.
    def to_app
      app = @map ? generate_map(@run, @map) : @run
      fail "missing run or map statement" unless app
      app.freeze if @freeze_app
      app = @use.reverse.inject(app) { |a, e| e[a].tap { |x| x.freeze if @freeze_app } }
      @warmup.call(app) if @warmup
      app
    end

    # Call the Rack application generated by this builder instance. Note that
    # this rebuilds the Rack application and runs the warmup code (if any)
    # every time it is called, so it should not be used if performance is important.
    def call(env)
      to_app.call(env)
    end

    private

    # Generate a URLMap instance by generating new Rack applications for each
    # map block in this instance.
    def generate_map(default_app, mapping)
      mapped = default_app ? { '/' => default_app } : {}
      mapping.each { |r, b| mapped[r] = self.class.new(default_app, &b).to_app }
      URLMap.new(mapped)
    end
  end
end
