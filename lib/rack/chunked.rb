require 'rack/utils'

module Rack

  # Middleware that applies chunked transfer encoding to response bodies
  # when the response does not include a Content-Length header.
  class Chunked
    include Rack::Utils

    TERM = "\r\n".freeze
    TAIL = "0#{TERM}#{TERM}".freeze
    HTTP_1_0 = 'HTTP/1.0'.freeze

    def initialize(app)
      @app = app
    end

    def call(env)
      status, headers, body = @app.call(env)
      headers = HeaderHash.new(headers)

      if env[CGI_VARIABLE::HTTP_VERSION] == HTTP_1_0 ||
         STATUS_WITH_NO_ENTITY_BODY.include?(status) ||
         headers[HTTP_HEADER::CONTENT_LENGTH] ||
         headers[HTTP_HEADER::TRANSFER_ENCODING]
        [status, headers, body]
      else
        dup.chunk(status, headers, body)
      end
    end

    def chunk(status, headers, body)
      @body = body
      headers.delete(HTTP_HEADER::CONTENT_LENGTH)
      headers[HTTP_HEADER::TRANSFER_ENCODING] = 'chunked'
      [status, headers, self]
    end

    def each
      term = TERM
      @body.each do |chunk|
        size = bytesize(chunk)
        next if size == 0
        yield [size.to_s(16), term, chunk, term].join
      end
      yield TAIL
    end

    def close
      @body.close if @body.respond_to?(:close)
    end
  end
end
