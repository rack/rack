# frozen_string_literal: true

require "zlib"
require "time"  # for Time.httpdate

require_relative 'constants'
require_relative 'utils'
require_relative 'request'
require_relative 'body_proxy'

module Rack
  # This middleware enables content encoding of http responses,
  # usually for purposes of compression.
  #
  # Currently supported encodings:
  #
  # * gzip
  # * identity (no transformation)
  #
  # This middleware automatically detects when encoding is supported
  # and allowed. For example no encoding is made when a cache
  # directive of 'no-transform' is present, when the response status
  # code is one that doesn't allow an entity body, or when the body
  # is empty.
  #
  # Note that despite the name, Deflater does not support the +deflate+
  # encoding.
  class Deflater

    GZIP_MTIME = 0

    # Creates Rack::Deflater middleware. Options:
    #
    # :if :: a lambda enabling / disabling deflation based on returned boolean value
    #        (e.g <tt>use Rack::Deflater, :if => lambda { |*, body| sum=0; body.each { |i| sum += i.length }; sum > 512 }</tt>).
    #        However, be aware that calling `body.each` inside the block will break cases where `body.each` is not idempotent,
    #        such as when it is an +IO+ instance.
    # :include :: a list of content types that should be compressed. By default, all content types are compressed.
    # :sync :: determines if the stream is going to be flushed after every chunk.  Flushing after every chunk reduces
    #          latency for time-sensitive streaming applications, but hurts compression and throughput.
    #          Defaults to +true+.
    # :deflaters :: a hash of custom deflaters, where keys are encoding names and values are callables
    #              that take (headers, body) and return a deflated body object. When provided, these
    #              custom deflaters will be used if the client's accept-encoding header matches.
    def initialize(app, options = {})
      @app = app
      @condition = options[:if]
      @compressible_types = options[:include]
      @sync = options.fetch(:sync, true)
      @deflaters = options[:deflaters]
      @available_encodings = %w(gzip)
      @deflaters&.each_key { |key| @available_encodings << key }
      @available_encodings << 'identity'
      @available_encodings.freeze
    end

    def call(env)
      status, headers, body = response = @app.call(env)

      unless should_deflate?(env, status, headers, body)
        return response
      end

      request = Request.new(env)
      encoding = Utils.select_best_encoding(@available_encodings,
                                            request.accept_encoding)

      # Set the Vary HTTP header.
      vary = headers["vary"].to_s.split(",").map(&:strip)
      unless vary.include?("*") || vary.any?{|v| v.downcase == 'accept-encoding'}
        headers["vary"] = vary.push("Accept-Encoding").join(",")
      end

      case encoding
      when "gzip"
        headers['content-encoding'] = "gzip"
        headers.delete(CONTENT_LENGTH)
        # A body that responds to #call and not #each is a streaming body, and
        # iterating it with GzipStream would raise NoMethodError.
        response[2] = if body.respond_to?(:each)
          GzipStream.new(body, GZIP_MTIME, @sync)
        else
          GzipStreamingBody.new(body, GZIP_MTIME, @sync)
        end
        response
      when "identity"
        response
      else
        if deflater = @deflaters&.[](encoding)
          headers['content-encoding'] = encoding
          headers.delete(CONTENT_LENGTH)
          response[2] = deflater.call(headers, body)
          response
        else
          # Only possible encoding values here are 'gzip', 'identity', and nil
          message = "An acceptable encoding for the requested resource #{request.fullpath} could not be found."
          bp = Rack::BodyProxy.new([message]) { body.close if body.respond_to?(:close) }
          [406, { CONTENT_TYPE => "text/plain", CONTENT_LENGTH => message.length.to_s }, bp]
        end
      end
    end

    # Body class used for gzip encoded responses.
    class GzipStream

      BUFFER_LENGTH = 128 * 1_024

      # Initialize the gzip stream.  Arguments:
      # body :: Response body to compress with gzip
      # mtime :: The modification time of the body, used to set the
      #          modification time in the gzip header.
      # sync :: Whether to flush each gzip chunk as soon as it is ready.
      def initialize(body, mtime, sync)
        @body = body
        @mtime = mtime
        @sync = sync
      end

      # Yield gzip compressed strings to the given block.
      def each(&block)
        @writer = block
        gzip = ::Zlib::GzipWriter.new(self)
        gzip.mtime = @mtime if @mtime
        # @body.each is equivalent to @body.gets (slow)
        if @body.is_a? ::File # XXX: Should probably be ::IO
          while part = @body.read(BUFFER_LENGTH)
            gzip.write(part)
            gzip.flush if @sync
          end
        else
          @body.each { |part|
            # Skip empty strings, as they would result in no output,
            # and flushing empty parts would raise Zlib::BufError.
            next if part.empty?
            gzip.write(part)
            gzip.flush if @sync
          }
        end
      ensure
        gzip.finish
      end

      # Call the block passed to #each with the gzipped data.
      def write(data)
        @writer.call(data)
      end

      # Close the original body if possible.
      def close
        @body.close if @body.respond_to?(:close)
      end
    end

    # Body class used for gzip encoded responses whose body is a streaming body,
    # that is one that responds to #call and not #each.
    #
    # The body writes plain text to the stream it is handed, so it is handed a
    # stream that gzips what is written and forwards the result to the server's
    # stream. It responds to #call only: a body that also responded to #each
    # would be treated as an enumerable body.
    class GzipStreamingBody

      # Initialize the gzip streaming body.  Arguments:
      # body :: Response body to compress with gzip
      # mtime :: The modification time of the body, used to set the
      #          modification time in the gzip header.
      # sync :: Whether to flush each gzip chunk as soon as it is ready.
      def initialize(body, mtime, sync)
        @body = body
        @mtime = mtime
        @sync = sync
      end

      # Run the streaming body against a stream that compresses what it is
      # written and finishes the gzip stream afterwards, whether the body
      # closed the stream itself or not.
      def call(stream)
        compressed = CompressedStream.new(stream, @mtime, @sync)

        begin
          @body.call(compressed)
        ensure
          compressed.finish
        end
      end

      # Close the original body if possible.
      def close
        @body.close if @body.respond_to?(:close)
      end

      # The stream a streaming body writes to, as described in the Streaming
      # Body section of SPEC.rdoc. Everything written is gzipped into the
      # server's stream.
      class CompressedStream
        def initialize(stream, mtime, sync)
          @stream = stream
          @sync = sync
          @gzip = ::Zlib::GzipWriter.new(Sink.new(stream))
          @gzip.mtime = mtime if mtime
          @finished = false
          @closed = false
        end

        def write(data)
          data = data.to_s
          return 0 if data.empty?

          @gzip.write(data)
          @gzip.flush if @sync
          data.bytesize
        end

        def <<(data)
          write(data)
          self
        end

        def flush
          @gzip.flush
          @stream.flush if @stream.respond_to?(:flush)
          self
        end

        # Writes the gzip trailer. Called by the streaming body's stream, and by
        # GzipStreamingBody when the body returns without closing the stream.
        def finish
          return if @finished

          @finished = true
          @gzip.finish
        end

        def close
          return if @closed

          @closed = true
          finish
          @stream.close if @stream.respond_to?(:close)
        end

        def close_read
          @stream.close_read if @stream.respond_to?(:close_read)
        end

        def close_write
          close
        end

        def closed?
          @closed
        end

        def read(*arguments)
          @stream.read(*arguments)
        end

        # Where the gzip writer puts its output. It only needs to write, but
        # Zlib flushes through the underlying object too.
        class Sink
          def initialize(stream)
            @stream = stream
          end

          def write(data)
            @stream.write(data)
          end

          def flush
            @stream.flush if @stream.respond_to?(:flush)
          end
        end
      end
    end

    private

    # Whether the body should be compressed.
    def should_deflate?(env, status, headers, body)
      # Skip compressing empty entity body responses and responses with
      # no-transform set.
      if Utils::STATUS_WITH_NO_ENTITY_BODY.key?(status.to_i) ||
          /\bno-transform\b/.match?(headers[CACHE_CONTROL].to_s) ||
          headers['content-encoding']&.!~(/\bidentity\b/)
        return false
      end

      # Skip if @compressible_types are given and does not include request's content type
      return false if @compressible_types && !(headers.has_key?(CONTENT_TYPE) && @compressible_types.include?(headers[CONTENT_TYPE][/[^;]*/]))

      # Skip if @condition lambda is given and evaluates to false
      return false if @condition && !@condition.call(env, status, headers, body)

      # No point in compressing empty body, also handles usage with
      # Rack::Sendfile.
      return false if headers[CONTENT_LENGTH] == '0'

      true
    end
  end
end
