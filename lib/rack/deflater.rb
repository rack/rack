require "zlib"
require "stringio"
require "time"  # for Time.httpdate
require 'rack/utils'

module Rack
  class Deflater
    GZIP = "gzip".freeze
    DEFLATE = "deflate".freeze
    IDENTITY = "identity".freeze
    NO_TRANSFORM = /\bno-transform\b/i.freeze
    ACCEPT_ENCODING = "Accept-Encoding".freeze
    
    def initialize(app)
      @app = app
    end

    def call(env)
      status, headers, body = @app.call(env)
      headers = Utils::HeaderHash.new(headers)

      # Skip compressing empty entity body responses and responses with
      # no-transform set.
      if Utils::STATUS_WITH_NO_ENTITY_BODY.include?(status) ||
          headers[HTTP_HEADER::CACHE_CONTROL].to_s =~ NO_TRANSFORM
        return [status, headers, body]
      end

      request = Request.new(env)

      encoding = Utils.select_best_encoding(%w(gzip deflate identity),
                                            request.accept_encoding)

      # Set the Vary HTTP header.
      vary = headers[HTTP_HEADER::VARY].to_s.split(",").map { |v| v.strip }
      unless vary.include?("*") || vary.include?(ACCEPT_ENCODING)
        headers[HTTP_HEADER::VARY] = vary.push(ACCEPT_ENCODING).join(",")
      end

      case encoding
      when GZIP
        headers[HTTP_HEADER::CONTENT_ENCODING] = GZIP
        headers.delete(HTTP_HEADER::CONTENT_LENGTH)
        mtime = headers.key?(HTTP_HEADER::LAST_MODIFIED) ?
          Time.httpdate(headers[HTTP_HEADER::LAST_MODIFIED]) : Time.now
        [status, headers, GzipStream.new(body, mtime)]
      when DEFLATE
        headers[HTTP_HEADER::CONTENT_ENCODING] = DEFLATE
        headers.delete(HTTP_HEADER::CONTENT_LENGTH)
        [status, headers, DeflateStream.new(body)]
      when IDENTITY
        [status, headers, body]
      when nil
        message = "An acceptable encoding for the requested resource #{request.fullpath} could not be found."
        [406, {HTTP_HEADER::CONTENT_TYPE => "text/plain", HTTP_HEADER::CONTENT_LENGTH => message.length.to_s}, [message]]
      end
    end

    class GzipStream
      def initialize(body, mtime)
        @body = body
        @mtime = mtime
      end

      def each(&block)
        @writer = block
        gzip  =::Zlib::GzipWriter.new(self)
        gzip.mtime = @mtime
        @body.each { |part| gzip.write(part) }
        @body.close if @body.respond_to?(:close)
        gzip.close
        @writer = nil
      end

      def write(data)
        @writer.call(data)
      end
    end

    class DeflateStream
      DEFLATE_ARGS = [
        Zlib::DEFAULT_COMPRESSION,
        # drop the zlib header which causes both Safari and IE to choke
        -Zlib::MAX_WBITS,
        Zlib::DEF_MEM_LEVEL,
        Zlib::DEFAULT_STRATEGY
      ]

      def initialize(body)
        @body = body
      end

      def each
        deflater = ::Zlib::Deflate.new(*DEFLATE_ARGS)
        @body.each { |part| yield deflater.deflate(part) }
        @body.close if @body.respond_to?(:close)
        yield deflater.finish
        nil
      end
    end
  end
end
