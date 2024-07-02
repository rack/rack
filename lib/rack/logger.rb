# frozen_string_literal: true

require_relative 'constants'

warn "Rack::Logger is deprecated and will be removed in Rack 3.2.", uplevel: 1

module Rack
  class Logger
    # A minimal implementation that satisfies the Rack specification.
    class Output
      def initialize(delegate = STDOUT)
        @delegate = delegate
      end
      
      def puts(*arguments, &block)
        if block_given?
          arguments << yield
        end
        
        @delegate.puts(arguments.join(' '))
      end
      
      def info(*arguments, &block)
        puts(" INFO:", *arguments, &block)
      end
      
      def debug(*arguments, &block)
        puts("DEBUG:", *arguments, &block)
      end
      
      def warn(*arguments, &block)
        puts(" WARN:", *arguments, &block)
      end
      
      def error(*arguments, &block)
        puts("ERROR:", *arguments, &block)
      end
      
      def fatal(*arguments, &block)
        puts("FATAL:", *arguments, &block)
      end
    end
    
    def initialize(app, logger = nil)
      @app = app
      @logger = logger || Output.new
    end
    
    def call(env)
      env[RACK_LOGGER] ||= @logger
      @app.call(env)
    end
  end
end
