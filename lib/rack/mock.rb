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

    DEFAULT_ENV = {
      "rack.version" => [0,1],
      "rack.input" => StringIO.new,
      "rack.errors" => StringIO.new,
      "rack.multithread" => true,
      "rack.multiprocess" => true,
      "rack.run_once" => false,
    }

    def initialize(app)
      @app = app
    end

    def get(uri, opts={})    request("GET", uri, opts)    end
    def post(uri, opts={})   request("POST", uri, opts)   end
    def put(uri, opts={})    request("PUT", uri, opts)    end
    def delete(uri, opts={}) request("DELETE", uri, opts) end

    def request(method="GET", uri="", opts={})
      env = self.class.env_for(uri, opts.merge(:method => method))

      if opts[:lint]
        app = Rack::Lint.new(@app)
      else
        app = @app
      end

      errors = env["rack.errors"]
      MockResponse.new(*(app.call(env) + [errors]))
    end

    def self.env_for(uri="", opts={})
      uri = URI(uri)
      env = DEFAULT_ENV.dup

      env["REQUEST_METHOD"] = opts[:method] || "GET"
      env["SERVER_NAME"] = uri.host || "example.org"
      env["SERVER_PORT"] = uri.port ? uri.port.to_s : "80"
      env["QUERY_STRING"] = uri.query.to_s
      env["PATH_INFO"] = (!uri.path || uri.path.empty?) ? "/" : uri.path
      env["rack.url_scheme"] = uri.scheme || "http"

      env["SCRIPT_NAME"] = opts[:script_name] || ""

      if opts[:fatal]
        env["rack.errors"] = FatalWarner.new
      else
        env["rack.errors"] = StringIO.new
      end

      opts[:input] ||= ""
      if String === opts[:input]
        env["rack.input"] = StringIO.new(opts[:input])
      else
        env["rack.input"] = opts[:input]
      end

      opts.each { |field, value|
        env[field] = value  if String === field
      }

      env
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
