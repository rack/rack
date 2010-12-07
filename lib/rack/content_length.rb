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
         !headers[HTTP_HEADER::CONTENT_LENGTH] &&
         !headers[HTTP_HEADER::TRANSFER_ENCODING] &&
         body.respond_to?(:to_ary)

        length = 0
        body.each { |part| length += bytesize(part) }
        headers[HTTP_HEADER::CONTENT_LENGTH] = length.to_s
      end

      [status, headers, body]
    end
  end
end
