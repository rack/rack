# frozen_string_literal: true

module Rack
  # *Handlers* connect web servers with Rack.
  module Handler
    @handlers = {}

    # Register a named handler class.
    def self.register(name, klass)
      if klass.is_a?(String)
        warn "Calling Rack::Handler.register with a string is deprecated, use the class/module itself.", uplevel: 1
        
        klass = self.const_get(klass, false)
      end

      @handlers[name] = klass
    end

    def self.[](name)
      @handlers[name]
    end
  end
end
