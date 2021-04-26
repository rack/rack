# frozen_string_literal: true

module Rack

  # Sets the Content-Length header on responses that do not specify
  # a Content-Length or Transfer-Encoding header.  Note that this
  # does not fix responses that have an invalid Content-Length
  # header specified.
  class ContentLength
    include Rack::Utils

    def initialize(app)
      @app = app
    end

    def call(env)
      status, headers, body = @app.call(env)
      headers = HeaderHash[headers]

      if !STATUS_WITH_NO_ENTITY_BODY.key?(status.to_i) &&
         !headers[CONTENT_LENGTH] &&
         !headers[TRANSFER_ENCODING] &&
         body.respond_to?(:to_ary)

        body = body.to_ary
        headers[CONTENT_LENGTH] = body.sum(&:bytesize).to_s
      end

      [status, headers, body]
    end
  end
end
