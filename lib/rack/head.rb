# frozen_string_literal: true

require_relative 'constants'
require_relative 'body_proxy'

module Rack
  # Rack::Head returns an empty body for all HEAD requests. It leaves
  # all other requests unchanged.
  class Head
    def initialize(app)
      @app = app
    end

    def call(env)
      _, _, body = response = @app.call(env)

      if env[REQUEST_METHOD] == HEAD
        response[2] = Rack::BodyProxy.new([]) do
          body.close if body.respond_to? :close
        end
      end

      response
    end
  end
end
