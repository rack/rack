require 'rack/request'
require 'rack/utils'
require 'rack/body_proxy'
require 'time'

module Rack
  # Rack::Response provides a convenient interface to create a Rack
  # response.
  #
  # It allows setting of headers and cookies, and provides useful
  # defaults (an OK response with empty headers and body).
  #
  # You can use Response#write to iteratively generate your response,
  # but note that this is buffered by Rack::Response until you call
  # +finish+.  +finish+ however can take a block inside which calls to
  # +write+ are synchronous with the Rack response.
  #
  # Your application's +call+ should end returning Response#finish.

  class Response
    attr_accessor :length

    CHUNKED = 'chunked'.freeze

    def initialize(body=[], status=200, header={})
      @status = status.to_i
      @header = Utils::HeaderHash.new.merge(header)

      @chunked = CHUNKED == @header[TRANSFER_ENCODING]
      @writer  = lambda { |x| @body << x }
      @block   = nil

      @body = nil

      @body_input = nil
      self.body = body
      yield self  if block_given?
    end

    def body=(body)
      @length = 0
      # provide body#close and body#closed?
      @body = BodyProxy.new([]){}

      if body.respond_to? :to_str
        write body.to_str
      elsif body.respond_to?(:each)
        body.each { |part|
          write part.to_s
        }
      else
        raise TypeError, "stringable or iterable required"
      end

      # don't close input body until #finish, because body#close may be called first
      @body_input = body if body.respond_to?(:close)
    end

    attr_reader :header, :body
    attr_accessor :status

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
      close_input
      @block = block

      if [204, 205, 304].include?(status.to_i)
        header.delete CONTENT_TYPE
        header.delete CONTENT_LENGTH
        close
        [status.to_i, header, []]
      else
        [status.to_i, header, BodyProxy.new(self){}]
      end
    end
    alias to_a finish           # For *response
    alias to_ary finish         # For implicit-splat on Ruby 1.9.2

    def each(&callback)
      @body.each(&callback)
      @writer = callback
      @block.call(self)  if @block
    end

    # Append to body and update Content-Length.
    def write(str)
      s = str.to_s
      @length += s.bytesize unless @chunked
      @writer.call s

      header[CONTENT_LENGTH] = @length.to_s unless @chunked
      str
    end

    def close_input
      @body_input.close if @body_input != nil && @body_input.respond_to?(:close)
      @body_input = nil # remove reference to old body after closing
    end

    def close
      close_input
      body.close if body.respond_to?(:close)
    end

    def empty?
      @block == nil && @body.empty?
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

      def content_length
        cl = headers[CONTENT_LENGTH]
        cl ? cl.to_i : cl
      end

      def location
        headers["Location"]
      end
    end

    include Helpers
  end
end
