require_relative 'request'

module Rack
  class RequestWrapper
    def initialize(app)
      @app = app
    end

    def call(env)
      @app.call(Request[env])
    end
  end
end
