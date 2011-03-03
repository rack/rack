require 'rack/middleware'

module Rack
  # Rack::Config modifies the environment using the block given during
  # initialization.
  class Config < Rack::Middleware
    def initialize(app, &block)
      super(app)
      @block = block
    end

    def call(env)
      @block.call(env)
      super
    end
  end
end
