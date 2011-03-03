require 'rack/utils'
require 'rack/middleware'

module Rack

  # Middleware that applies chunked transfer encoding to response bodies
  # when the response does not include a Content-Length header.
  class Chunked < Rack::Middleware
    include Rack::Utils

    TERM = "\r\n"
    TAIL = "0#{TERM}#{TERM}"

    def call(env)
      status, headers, body = super
      headers = HeaderHash.new(headers)

      if env['HTTP_VERSION'] == 'HTTP/1.0' ||
         STATUS_WITH_NO_ENTITY_BODY.include?(status) ||
         headers['Content-Length'] ||
         headers['Transfer-Encoding']
        [status, headers, body]
      else
        dup.chunk(status, headers, body)
      end
    end

    def chunk(status, headers, body)
      @body = body
      headers.delete('Content-Length')
      headers['Transfer-Encoding'] = 'chunked'
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
