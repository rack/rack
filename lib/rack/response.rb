require 'rack/request'
require 'rack/utils'
require 'rack/body_proxy'
require 'rack/media_type'
require 'time'

module Rack
  # Rack::Response provides a convenient interface to create a Rack
  # response.
  #
  # It allows setting of headers and cookies, and provides useful
  # defaults (an OK response with empty headers and body).
  #
  # You can add content to the Response body through the constructor parameter,
  # or by calling +write+.
  #
  # You can also add unbuffered content to the Response body by passing a block
  # to +finish+, inside which calls to +write+ are synchronous with the Rack response.
  #
  # In Rack v2+, all body content is unbuffered by default, and the Content-Length header will not be updated.
  #
  # You may explicitly configure buffering body content by setting the +buffered+ constructor parameter,
  # or by using the +Response.buffered+/+Response.unbuffered+ factory methods.
  #
  #
  # Your application's +call+ should end returning Response#finish.

  class Response
    attr_reader :header, :body
    attr_accessor :status, :length

    def initialize(body=[], status=200, header={}, buffered=false)
      @status = status.to_i
      @header = Utils::HeaderHash.new.merge(header)
      @writer  = lambda { |x| @body_inputs << x; @length += x.bytesize }
      @block   = nil
      @read_body = buffered
      self.body = body
      yield self  if block_given?
    end

    # Default in <= 1.x
    def self.buffered(body=[], status=200, header={})
      self.new body, status, header, true
    end

    # Default in >= 2.x
    def self.unbuffered(body=[], status=200, header={})
      self.new body, status, header, false
    end

    def body=(body)
      @body = BodyProxy.new(self){}
      @open_bodies = []
      @body_inputs = []
      @length = 0
      write body
    end
    private :body=

    def [](key)
      header[key]
    end

    def []=(key, value)
      header[key] = value
    end

    def set_cookie(key, value)
      Utils.set_cookie_header!(header, key, value)
    end

    def delete_cookie(key, value={})
      Utils.delete_cookie_header!(header, key, value)
    end

    def redirect(target, status=302)
      self.status = status
      self["Location"] = target
    end

    def finish(&block)
      @block = block

      if [204, 205, 304].include?(status.to_i)
        header.delete CONTENT_TYPE
        header.delete CONTENT_LENGTH
        close
        [status.to_i, header, []]
      else
        [status.to_i, header, body]
      end
    end
    alias to_a finish           # For *response
    alias to_ary finish         # For implicit-splat on Ruby 1.9.2

    def each(&callback)
      raise "cannot iterate over closed Response" if @body.closed?
      @body_inputs.each {|b| iterate_body(b, &callback)}
      @body_inputs.clear
      @read_body = true
      @writer = callback
      @block.call(self)  if @block
    end

    def iterate_body(body, &callback)
      if body.respond_to? :to_str
        callback.call(body.to_str)
      elsif body.respond_to? :each
        body.each(&callback)
      else
        raise TypeError, "stringable or iterable required"
      end
    end

    # Append body object to response.
    def write(body)
      raise "cannot write to closed Response" if @body.closed?
      raise TypeError, "stringable or iterable required" unless body.respond_to?(:each) || body.respond_to?(:to_str)
      if @read_body
        old_length = @length
        iterate_body(body, &@writer)
        self.content_length = @length if @length != old_length
      else
        @body_inputs << body
      end
      # defer closing all body objects until #close is called
      @open_bodies << body if body.respond_to?(:close)
      body
    end

    def close
      @body.close
      @open_bodies.each do |b|
        b.close if b != nil && b.respond_to?(:close) &&
            !(b.respond_to?(:closed?) && b.closed?) # prevent double-close IOError on streams
      end
      @open_bodies.clear # remove references
    end

    def empty?
      @block == nil && @body_inputs.all?(&:empty?)
    end

    alias headers header

    module Helpers
      def invalid?;             status < 100 || status >= 600;        end

      def informational?;       status >= 100 && status < 200;        end
      def successful?;          status >= 200 && status < 300;        end
      def redirection?;         status >= 300 && status < 400;        end
      def client_error?;        status >= 400 && status < 500;        end
      def server_error?;        status >= 500 && status < 600;        end

      def ok?;                  status == 200;                        end
      def created?;             status == 201;                        end
      def accepted?;            status == 202;                        end
      def no_content?;          status == 204;                        end
      def moved_permanently?;   status == 301;                        end
      def bad_request?;         status == 400;                        end
      def unauthorized?;        status == 401;                        end
      def forbidden?;           status == 403;                        end
      def not_found?;           status == 404;                        end
      def method_not_allowed?;  status == 405;                        end
      def precondition_failed?; status == 412;                        end
      def i_m_a_teapot?;        status == 418;                        end
      def unprocessable?;       status == 422;                        end

      def redirect?;            [301, 302, 303, 307].include? status; end

      # Headers
      attr_reader :headers, :original_headers

      def include?(header)
        !!headers[header]
      end

      def content_type
        headers[CONTENT_TYPE]
      end

      def media_type
        @media_type ||= MediaType.type(content_type)
      end

      def media_type_params
        @media_type_params ||= MediaType.params(content_type)
      end

      def content_length
        cl = headers[CONTENT_LENGTH]
        cl ? cl.to_i : cl
      end

      def location
        headers["Location"]
      end

      def content_length=(length)
        header[CONTENT_LENGTH] = length.to_s unless chunked?
      end

      CHUNKED = 'chunked'.freeze
      def chunked?
        header[TRANSFER_ENCODING] == CHUNKED
      end
    end

    include Helpers
  end
end
