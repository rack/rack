require 'rack/utils'
require 'rack/body_proxy'

module Rack

  # Sets the Content-Length header on responses with fixed-length bodies.
  class ContentLength
    include Rack::Utils

    def initialize(app)
      @app = app
    end

    def call(env)
      status, headers, body = @app.call(env)
      headers = HeaderHash.new(headers)

      if !STATUS_WITH_NO_ENTITY_BODY.include?(status.to_i) &&
         !headers['Content-Length'] &&
         !headers['Transfer-Encoding'] &&
         body.respond_to?(:to_ary)

        obody = body
        body, length = [], 0
        obody.each { |part| body << part; length += bytesize(part) }

        body = BodyProxy.new(body) do
          obody.close if obody.respond_to?(:close)
        end

        headers['Content-Length'] = length.to_s
      end

      [status, headers, body]
    end
  end
end
