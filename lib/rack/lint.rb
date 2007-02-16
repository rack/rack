module Rack
  class Lint
    def initialize(app)
      @app = app
    end

    class LintError < RuntimeError; end
    module Assertion
      def assert(message, &block)
        unless block.call
          raise LintError, message
        end
      end
    end
    include Assertion

    def call(env=nil)
      assert("No env given") { env }
      check_env env

      env['rack.input'] = InputWrapper.new(env['rack.input'])
      env['rack.errors'] = ErrorWrapper.new(env['rack.errors'])

      status, headers, @body = @app.call(env)
      check_status status
      check_headers headers
      check_content_type status, headers
      [status, headers, self]
    end

    def check_env(env)
      assert("env #{env.inspect} is not a Hash, but #{env.class}") {
        env.instance_of? Hash
      }
      
      %w[REQUEST_METHOD SERVER_NAME SERVER_PORT
         QUERY_STRING
         rack.version rack.input rack.errors
         rack.multithread rack.multiprocess rack.run_once].each { |header|
        assert("env missing required key #{header}") { env.include? header }
      }

      %w[HTTP_CONTENT_TYPE HTTP_CONTENT_LENGTH].each { |header|
        assert("env contains #{header}, must use #{header[5,-1]}") {
          not env.include? header
        }
      }

      env.each { |key, value|
        next  if key.include? "."   # Skip extensions
        assert("env variable #{key} has non-string value #{value.inspect}") {
          value.instance_of? String
        }
      }

      assert("rack.version must be an Array, was #{env["rack.version"].class}") {
        env["rack.version"].instance_of? Array
      }
      assert("rack.url_scheme unknown: #{env["rack.url_scheme"].inspect}") {
        %w[http https].include? env["rack.url_scheme"]
      }

      check_input env["rack.input"]
      check_error env["rack.errors"]

      assert("REQUEST_METHOD unknown: #{env["REQUEST_METHOD"]}") {
        %w[GET POST PUT DELETE
           HEAD OPTIONS TRACE].include?(env["REQUEST_METHOD"])
      }

      assert("SCRIPT_NAME must start with /") {
        !env.include?("SCRIPT_NAME") ||
        env["SCRIPT_NAME"] == "" ||
        env["SCRIPT_NAME"] =~ /\A\//
      }
      assert("PATH_INFO must start with /") {
        !env.include?("PATH_INFO") ||
        env["PATH_INFO"] == "" ||
        env["PATH_INFO"] =~ /\A\//
      }
      assert("Invalid CONTENT_LENGTH: #{env["CONTENT_LENGTH"]}") {
        !env.include?("CONTENT_LENGTH") || env["CONTENT_LENGTH"] =~ /\A\d+\z/
      }

      assert("One of SCRIPT_NAME or PATH_INFO must be set (make PATH_INFO '/' if SCRIPT_NAME is empty)") {
        env["SCRIPT_NAME"] || env["PATH_INFO"]
      }
      assert("SCRIPT_NAME cannot be '/', make it '' and PATH_INFO '/'") {
        env["SCRIPT_NAME"] != "/"
      }
    end

    def check_input(input)
      [:gets, :read].each { |method|
        assert("rack.input #{input} does not respond to ##{method}") {
          input.respond_to? method
        }
      }
    end

    def check_error(error)
      [:puts, :write, :flush].each { |method|
        assert("rack.error #{error} does not respond to ##{method}") {
          error.respond_to? method
        }
      }
    end

    def check_status(status)
      assert("Status must be >100 seen as integer") { status.to_i > 100 }
    end

    def check_headers(header)
      assert("header should respond to #each") { header.respond_to? :each }
      header.each { |key, value|
        assert("header key must be a string, was #{key.class}") {
          key.instance_of? String
        }
        assert("header must not contain Status") { key.downcase != "status" }
        assert("header names must not contain : or \\n") { key !~ /[:\n]/ }
        assert("header names must not end in - or _") { key !~ /[-_]\z/ }
        assert("invalid header name: #{key}") { key =~ /\A[a-zA-Z][a-zA-Z0-9_-]*\z/ }
        assert("invalid header name: #{key.inspect}") { key !~ /[\000-\037]/ }

        assert("header values must respond to #each") { value.respond_to? :each }
        value.each { |item|
          assert("header values must consist of Strings") {
            item.instance_of?(String)
          }
        }
      }
    end

    def check_content_type(status, headers)
      headers.each { |key, value|
        if key.downcase == "content-type"
          assert("Content-Type header found in #{status} response, not allowed"){
            not [201, 204, 304].include? status.to_i
          }
          return
        end
      }
      assert("No Content-Type header found") { false }
    end

    def each
      @closed = false
      @body.each { |part|
        assert("Body yielded non-string value #{part.inspect}") {
          part.instance_of? String
        }
        yield part
      }
      # XXX howto: assert("Body has not been closed") { @closed }
    end

    def close
      @closed = true
      @body.close  if @body.respond_to?(:close)
    end

    class InputWrapper
      include Assertion

      def initialize(input)
        @input = input
      end

      def gets(*args)
        assert("rack.input#gets called with arguments") { args.size == 0 }
        v = @input.gets
        assert("rack.input#gets didn't return a String") { v.instance_of? String }
        v
      end

      def read(*args)
        assert("rack.input#read called with arguments") { args.size == 0 }
        v = @input.read
        assert("rack.input#read didn't return a String") { v.instance_of? String }
        v
      end

      def each(*args)
        assert("rack.input#each called with arguments") { args.size == 0 }
        @input.each { |line|
          assert("rack.input#each didn't yield a String") {
            line.instance_of? String
          }
          yield line
        }
      end

      def close(*args)
        assert("rack.input#close must not be called") { false }
      end
    end

    class ErrorWrapper
      include Assertion

      def initialize(error)
        @error = error
      end

      def puts(str)
        @error.puts str
      end

      def write(str)
        assert("rack.errors#write not called with a String") { str.instance_of? String }
        @error.write str
      end

      def flush
        @error.flush
      end

      def close(*args)
        assert("rack.errors#close must not be called") { false }
      end
    end
  end
end
