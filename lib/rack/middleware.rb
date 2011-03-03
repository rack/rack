module Rack
  # An abstract base class for middleware applications.  Middleware *are not*
  # required to conform to this interface, so do not expect all middleware to
  # respond to +app+.
  class Middleware
    attr_accessor :app

    def initialize(app)
      @app = app
    end

    def call(env)
      app.call(env)
    end
  end
end
