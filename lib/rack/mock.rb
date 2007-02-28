require 'uri'
require 'stringio'
require 'rack/lint'
require 'rack/utils'

module Rack
  class MockRequest
    class FatalWarning < RuntimeError
    end

    class FatalWarner
      def puts(warning)
        raise FatalWarning, warning
      end

      def write(warning)
        raise FatalWarning, warning
      end

      def flush
      end
    end

    def initialize(app)
      @app = app
    end

    DEFAULT_ENV = {
      "REQUEST_METHOD" => "GET",
      "SERVER_NAME" => "example.org",
      "SERVER_PORT" => "80",
      "QUERY_STRING" => "",
      "rack.version" => [0,1],
      "rack.input" => StringIO.new,
      "rack.errors" => StringIO.new,
      "rack.multithread" => true,
      "rack.multiprocess" => true,
      "rack.run_once" => false,
      "rack.url_scheme" => "http",
      "PATH_INFO" => "/",
    }

    def get(uri, opts={})
      uri = URI(uri)
      env = DEFAULT_ENV.dup

      env["REQUEST_METHOD"] = "GET"
      env["SERVER_NAME"] = uri.host || "example.org"
      env["SERVER_PORT"] = uri.port ? uri.port.to_s : "80"
      env["QUERY_STRING"] = uri.query.to_s
      env["PATH_INFO"] = uri.path.empty? ? "/" : uri.path
      env["rack.url_scheme"] = uri.scheme || "http"

      if opts[:fatal]
        env["rack.errors"] = FatalWarner.new
      else
        env["rack.errors"] = errors = StringIO.new
      end

      if opts[:input]
        if String === opts[:input]
          env["rack.input"] = StringIO.new(opts[:input])
        else
          env["rack.input"] = opts[:input]
        end
      end

      if opts[:lint]
        app = Rack::Lint.new(@app)
      else
        app = @app
      end

      MockResponse.new(*(app.call(env) + [errors]))
    end
  end

  class MockResponse
    def initialize(status, headers, body, errors=StringIO.new(""))
      @status = status.to_i

      @original_headers = headers
      @headers = Rack::Utils::HeaderHash.new
      headers.each { |field, values|
        values.each { |value|
          @headers[field] = value
        }
      }

      @body = ""
      body.each { |part| @body << part }

      @errors = errors.string
    end

    # Status
    attr_reader :status

    def invalid?;       @status < 100 || @status >= 600;       end

    def informational?; @status >= 100 && @status < 200;       end
    def successful?;    @status >= 200 && @status < 300;       end
    def redirection?;   @status >= 300 && @status < 400;       end
    def client_error?;  @status >= 400 && @status < 500;       end
    def server_error?;  @status >= 500 && @status < 600;       end

    def ok?;            @status == 200;                        end
    def forbidden?;     @status == 403;                        end
    def not_found?;     @status == 404;                        end

    def redirect?;      [301, 302, 303, 307].include? @status; end
    def empty?;         [201, 204, 304].include?      @status; end

    # Headers
    attr_reader :headers, :original_headers

    def include?(header)
      !!headers[header]
    end

    def [](field)
      headers[field]
    end

    def content_type
      headers["Content-Type"]
    end

    def content_length
      cl = headers["Content-Length"]
      cl ? cl.to_i : cl
    end

    def location
      headers["Location"]
    end


    # Body
    attr_reader :body

    def =~(other)
      @body =~ other
    end

    def match(other)
      @body.match other
    end


    # Errors
    attr_accessor :errors
  end
end
