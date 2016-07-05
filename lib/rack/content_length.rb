require 'rack/utils'

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
         (body.respond_to?(:to_ary) || body.respond_to?(:to_str))

        length = 0
        if body.respond_to?(:to_ary)
          obody = body
          body = []
          obody.each { |part| body << part; length += bytesize(part) }
          obody.close if obody.respond_to?(:close)
        elsif body.respond_to?(:to_str)
          length = body.to_str.size
        end
        headers['Content-Length'] = length.to_s
      end

      [status, headers, body]
    end
  end
end
