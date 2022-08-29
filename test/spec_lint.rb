# frozen_string_literal: true

require_relative 'helper'
require 'tempfile'

separate_testing do
  require_relative '../lib/rack/lint'
  require_relative '../lib/rack/mock_request'
end

describe Rack::Lint do
  valid_app = lambda do |env|
    [200, { "content-type" => "test/plain", "content-length" => "3" }, ["foo"]]
  end

  def env(*args)
    Rack::MockRequest.env_for("/", *args)
  end

  it "pass valid request" do
    Rack::Lint.new(valid_app).call(env({})).first.must_equal 200
  end

  it "notice fatal errors" do
    lambda { Rack::Lint.new(nil).call }.must_raise(Rack::Lint::LintError).
      message.must_match(/No env given/)
  end

  it "notice environment errors" do
    lambda { Rack::Lint.new(nil).call 5 }.must_raise(Rack::Lint::LintError).
      message.must_match(/not a Hash/)

    lambda { Rack::Lint.new(nil).call({}.freeze) }.must_raise(Rack::Lint::LintError).
      message.must_match(/env should not be frozen, but is/)


    lambda {
      e = env
      e.delete("REQUEST_METHOD")
      Rack::Lint.new(nil).call(e)
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/missing required key REQUEST_METHOD/)

    lambda {
      e = env
      e.delete("SERVER_NAME")
      Rack::Lint.new(nil).call(e)
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/missing required key SERVER_NAME/)

    lambda {
      e = env
      e.delete("SERVER_PROTOCOL")
      Rack::Lint.new(nil).call(e)
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/missing required key SERVER_PROTOCOL/)

    lambda {
      e = env
      e["SERVER_PROTOCOL"] = 'Foo'
      Rack::Lint.new(nil).call(e)
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/env\[SERVER_PROTOCOL\] does not match HTTP/)

    lambda {
      e = env
      e["HTTP_VERSION"] = 'HTTP/1.0'
      Rack::Lint.new(nil).call(e)
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/env\[HTTP_VERSION\] does not equal env\[SERVER_PROTOCOL\]/)

    lambda {
      Rack::Lint.new(nil).call(env("HTTP_CONTENT_TYPE" => "text/plain"))
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/contains HTTP_CONTENT_TYPE/)

    lambda {
      Rack::Lint.new(nil).call(env("HTTP_CONTENT_LENGTH" => "42"))
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/contains HTTP_CONTENT_LENGTH/)

    lambda {
      Rack::Lint.new(nil).call(env("FOO" => Object.new))
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/non-string value/)

    lambda {
      Rack::Lint.new(nil).call(env("rack.url_scheme" => "gopher"))
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/url_scheme unknown/)

    lambda {
      Rack::Lint.new(nil).call(env("rack.session" => []))
    }.must_raise(Rack::Lint::LintError).
      message.must_equal "session [] must respond to store and []="

    Rack::Lint.new(valid_app).call(env("rack.session" => {}))[0].must_equal 200

    lambda {
      Rack::Lint.new(nil).call(env("rack.session" => {}.freeze))
    }.must_raise(Rack::Lint::LintError).
      message.must_equal "session {} must respond to to_hash and return unfrozen Hash instance"

    obj = {}
    obj.singleton_class.send(:undef_method, :to_hash)
    lambda {
      Rack::Lint.new(nil).call(env("rack.session" => obj))
    }.must_raise(Rack::Lint::LintError).
      message.must_equal "session {} must respond to to_hash and return unfrozen Hash instance"

    obj.singleton_class.send(:undef_method, :clear)
    lambda {
      Rack::Lint.new(nil).call(env("rack.session" => obj))
    }.must_raise(Rack::Lint::LintError).
      message.must_equal "session {} must respond to clear"

    obj.singleton_class.send(:undef_method, :delete)
    lambda {
      Rack::Lint.new(nil).call(env("rack.session" => obj))
    }.must_raise(Rack::Lint::LintError).
      message.must_equal "session {} must respond to delete"

    obj.singleton_class.send(:undef_method, :fetch)
    lambda {
      Rack::Lint.new(nil).call(env("rack.session" => obj))
    }.must_raise(Rack::Lint::LintError).
      message.must_equal "session {} must respond to fetch and []"

    obj = Object.new
    def obj.inspect; '[]' end
    lambda {
      Rack::Lint.new(nil).call(env("rack.logger" => obj))
    }.must_raise(Rack::Lint::LintError).
      message.must_equal "logger [] must respond to info"

    def obj.info(*) end
    lambda {
      Rack::Lint.new(nil).call(env("rack.logger" => obj))
    }.must_raise(Rack::Lint::LintError).
      message.must_equal "logger [] must respond to debug"

    def obj.debug(*) end
    lambda {
      Rack::Lint.new(nil).call(env("rack.logger" => obj))
    }.must_raise(Rack::Lint::LintError).
      message.must_equal "logger [] must respond to warn"

    def obj.warn(*) end
    lambda {
      Rack::Lint.new(nil).call(env("rack.logger" => obj))
    }.must_raise(Rack::Lint::LintError).
      message.must_equal "logger [] must respond to error"

    def obj.error(*) end
    lambda {
      Rack::Lint.new(nil).call(env("rack.logger" => obj))
    }.must_raise(Rack::Lint::LintError).
      message.must_equal "logger [] must respond to fatal"

    def obj.fatal(*) end
    Rack::Lint.new(valid_app).call(env("rack.logger" => obj))[0].must_equal 200

    lambda {
      Rack::Lint.new(nil).call(env("rack.multipart.buffer_size" => 0))
    }.must_raise(Rack::Lint::LintError).
      message.must_equal "rack.multipart.buffer_size must be an Integer > 0 if specified"

    Rack::Lint.new(valid_app).call(env("rack.multipart.buffer_size" => 1))[0].must_equal 200

    lambda {
      Rack::Lint.new(nil).call(env("rack.multipart.tempfile_factory" => Tempfile))
    }.must_raise(Rack::Lint::LintError).
      message.must_equal "rack.multipart.tempfile_factory must respond to #call"

    lambda {
      Rack::Lint.new(lambda { |env|
        env['rack.multipart.tempfile_factory'].call("testfile", "text/plain")
      }).call(env("rack.multipart.tempfile_factory" => lambda { |filename, content_type| Object.new }))
    }.must_raise(Rack::Lint::LintError).
      message.must_equal "rack.multipart.tempfile_factory return value must respond to #<<"

    lambda {
      Rack::Lint.new(lambda { |env|
        env['rack.multipart.tempfile_factory'].call("testfile", "text/plain")
        []
      }).call(env("rack.multipart.tempfile_factory" => lambda { |filename, content_type| String.new }))
    }.must_raise(Rack::Lint::LintError).
      message.must_equal "response array has 0 elements instead of 3"

    lambda {
      Rack::Lint.new(nil).call(env("SERVER_PORT" => "howdy"))
    }.must_raise(Rack::Lint::LintError).
      message.must_equal 'env[SERVER_PORT] is not an Integer'

    lambda {
      Rack::Lint.new(nil).call(env("SERVER_NAME" => "\u1234"))
    }.must_raise(Rack::Lint::LintError).
      message.must_equal "\u1234 must be a valid authority"

    lambda {
      Rack::Lint.new(nil).call(env("HTTP_HOST" => "\u1234"))
    }.must_raise(Rack::Lint::LintError).
      message.must_equal "\u1234 must be a valid authority"

    lambda {
      Rack::Lint.new(nil).call(env("REQUEST_METHOD" => "FUCKUP?"))
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/REQUEST_METHOD/)

    lambda {
      Rack::Lint.new(nil).call(env("REQUEST_METHOD" => "OOPS?\b!"))
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/OOPS\?\\/)

    lambda {
      Rack::Lint.new(nil).call(env("SCRIPT_NAME" => "howdy"))
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/must start with/)

    lambda {
      Rack::Lint.new(nil).call(env("PATH_INFO" => "../foo"))
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/must start with/)

    lambda {
      Rack::Lint.new(nil).call(env("CONTENT_LENGTH" => "xcii"))
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/Invalid CONTENT_LENGTH/)

    lambda {
      Rack::Lint.new(nil).call(env("QUERY_STRING" => nil))
    }.must_raise(Rack::Lint::LintError).
      message.must_include('env variable QUERY_STRING has non-string value nil')

    lambda {
      Rack::Lint.new(nil).call(env("QUERY_STRING" => "\u1234"))
    }.must_raise(Rack::Lint::LintError).
      message.must_include('env variable QUERY_STRING has value containing non-ASCII characters and has non-ASCII-8BIT encoding')

    Rack::Lint.new(lambda { |env|
                     [200, {}, []]
                   }).call(env("QUERY_STRING" => "\u1234".b)).first.must_equal 200

    lambda {
      e = env
      e.delete("PATH_INFO")
      e.delete("SCRIPT_NAME")
      Rack::Lint.new(nil).call(e)
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/One of .* must be set/)

    lambda {
      Rack::Lint.new(nil).call(env("SCRIPT_NAME" => "/"))
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/cannot be .* make it ''/)

    lambda {
      Rack::Lint.new(nil).call(env("rack.response_finished" => "not a callable"))
    }.must_raise(Rack::Lint::LintError).
    message.must_match(/rack.response_finished must be an array of callable objects/)

    lambda {
      Rack::Lint.new(nil).call(env("rack.response_finished" => [-> (env) {}, "not a callable"]))
    }.must_raise(Rack::Lint::LintError).
    message.must_match(/rack.response_finished values must respond to call/)
  end

  it "notice input errors" do
    lambda {
      Rack::Lint.new(nil).call(env("rack.input" => ""))
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/does not respond to #gets/)

    lambda {
      input = Object.new
      def input.binmode?
        false
      end
      Rack::Lint.new(nil).call(env("rack.input" => input))
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/is not opened in binary mode/)

    lambda {
      input = Object.new
      def input.external_encoding
        result = Object.new
        def result.name
          "US-ASCII"
        end
        result
      end
      Rack::Lint.new(nil).call(env("rack.input" => input))
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/does not have ASCII-8BIT as its external encoding/)
  end

  it "notice error errors" do
    lambda {
      io = StringIO.new
      io.binmode
      Rack::Lint.new(nil).call(env("rack.errors" => "", "rack.input" => io))
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/does not respond to #puts/)
  end

  it "notice response errors" do
    lambda {
      Rack::Lint.new(lambda { |env|
                       ""
                     }).call(env({}))
    }.must_raise(Rack::Lint::LintError).
      message.must_include('response is not an Array, but String')

    lambda {
      Rack::Lint.new(lambda { |env|
                       [nil, nil, nil, nil]
                     }).call(env({}))
    }.must_raise(Rack::Lint::LintError).
      message.must_include('response array has 4 elements instead of 3')
  end

  it "notice status errors" do
    lambda {
      Rack::Lint.new(lambda { |env|
                       ["cc", {}, ""]
                     }).call(env({}))
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/must be an Integer >=100/)

    lambda {
      Rack::Lint.new(lambda { |env|
                       [42, {}, ""]
                     }).call(env({}))
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/must be an Integer >=100/)

    lambda {
      Rack::Lint.new(lambda { |env|
                       ["200", {}, ""]
                     }).call(env({}))
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/must be an Integer >=100/)
  end

  it "notice header errors" do
    obj = Object.new
    def obj.each; end
    lambda {
      io = StringIO.new('a')
      io.binmode
      Rack::Lint.new(lambda { |env|
                       env['rack.input'].each{ |x| }
                       [200, obj, []]
                     }).call(env({ "rack.input" => io }))
    }.must_raise(Rack::Lint::LintError).
      message.must_equal "headers object should be a hash, but isn't (got Object as headers)"
    lambda {
      Rack::Lint.new(lambda { |env|
                       [200, {}.freeze, []]
                     }).call(env({}))
    }.must_raise(Rack::Lint::LintError).
      message.must_equal "headers object should not be frozen, but is"


    lambda {
      Rack::Lint.new(lambda { |env|
                       [200, { true => false }, []]
                     }).call(env({}))
    }.must_raise(Rack::Lint::LintError).
      message.must_equal "header key must be a string, was TrueClass"

    lambda {
      Rack::Lint.new(lambda { |env|
                       [200, { "status" => "404" }, []]
                     }).call(env({}))
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/must not contain status/)

    # From RFC 7230:<F24><F25>
    # Most HTTP header field values are defined using common syntax
    # components (token, quoted-string, and comment) separated by
    # whitespace or specific delimiting characters.  Delimiters are chosen
    # from the set of US-ASCII visual characters not allowed in a token
    # (DQUOTE and "(),/:;<=>?@[\]{}"). Rack also doesn't allow uppercase
    # ASCII (A-Z) in header keys.
    #
    #   token          = 1*tchar
    #
    #   tchar          = "!" / "#" / "$" / "%" / "&" / "'" / "*"
    #                 / "+" / "-" / "." / "^" / "_" / "`" / "|" / "~"
    #                 / DIGIT / ALPHA
    #                 ; any VCHAR, except delimiters
    invalid_headers = 0.upto(31).map(&:chr) + %W<( ) , / : ; < = > ? @ [ \\ ] { } \x7F>
    invalid_headers.each do |invalid_header|
      lambda {
        Rack::Lint.new(lambda { |env|
          [200, { invalid_header => "text/plain" }, []]
        }).call(env({}))
      }.must_raise(Rack::Lint::LintError, "on invalid header: #{invalid_header}").
      message.must_equal("invalid header name: #{invalid_header}")
    end
    ('A'..'Z').each do |invalid_header|
      lambda {
        Rack::Lint.new(lambda { |env|
          [200, { invalid_header => "text/plain" }, []]
        }).call(env({}))
      }.must_raise(Rack::Lint::LintError, "on invalid header: #{invalid_header}").
      message.must_equal("uppercase character in header name: #{invalid_header}")
    end
    valid_headers = 0.upto(127).map(&:chr) - invalid_headers - ('A'..'Z').to_a
    valid_headers.each do |valid_header|
      Rack::Lint.new(lambda { |env|
                       [200, { valid_header => "text/plain" }, []]
                     }).call(env({})).first.must_equal 200
    end

    lambda {
      Rack::Lint.new(lambda { |env|
                       [200, { "foo" => Object.new }, []]
                     }).call(env({}))
    }.must_raise(Rack::Lint::LintError).
      message.must_equal "a header value must be a String or Array of Strings, but the value of 'foo' is a Object"

    lambda {
      Rack::Lint.new(lambda { |env|
                       [200, { "foo-bar" => "text\000plain" }, []]
                     }).call(env({}))
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/invalid header/)

    lambda {
      Rack::Lint.new(lambda { |env|
                     [200, [%w(content-type text/plain), %w(content-length 0)], []]
                     }).call(env({}))
    }.must_raise(Rack::Lint::LintError).
      message.must_equal "headers object should be a hash, but isn't (got Array as headers)"

  end

  it "notice content-type errors" do
    # lambda {
    #   Rack::Lint.new(lambda { |env|
    #                    [200, {"content-length" => "0"}, []]
    #                  }).call(env({}))
    # }.must_raise(Rack::Lint::LintError).
    #   message.must_match(/No content-type/)

    [100, 101, 204, 304].each do |status|
      lambda {
        Rack::Lint.new(lambda { |env|
                         [status, { "content-type" => "text/plain", "content-length" => "0" }, []]
                       }).call(env({}))
      }.must_raise(Rack::Lint::LintError).
        message.must_match(/content-type header found/)
    end
  end

  it "notice content-length errors" do
    [100, 101, 204, 304].each do |status|
      lambda {
        Rack::Lint.new(lambda { |env|
                         [status, { "content-length" => "0" }, []]
                       }).call(env({}))
      }.must_raise(Rack::Lint::LintError).
        message.must_match(/content-length header found/)
    end

    lambda {
      Rack::Lint.new(lambda { |env|
                       [200, { "content-type" => "text/plain", "content-length" => "1" }, []]
                     }).call(env({}))[2].each { }
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/content-length header was 1, but should be 0/)
  end

  it "notice body errors" do
    lambda {
      body = Rack::Lint.new(lambda { |env|
                               [200, { "content-type" => "text/plain", "content-length" => "3" }, [1, 2, 3]]
                             }).call(env({}))[2]
      body.each { |part| }
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/yielded non-string/)

    lambda {
      body = Rack::Lint.new(lambda { |env|
                               [200, { "content-type" => "text/plain", "content-length" => "3" }, Object.new]
                             }).call(env({}))[2]
      body.respond_to?(:to_ary).must_equal false
      body.each { |part| }
    }.must_raise(Rack::Lint::LintError).
      message.must_equal 'Enumerable Body must respond to each'

    lambda {
      body = Rack::Lint.new(lambda { |env|
                               [200, { "content-type" => "text/plain", "content-length" => "0" }, []]
                             }).call(env({}))[2]
      body.each { |part| }
      body.each { |part| }
    }.must_raise(Rack::Lint::LintError).
      message.must_equal 'Response body must only be invoked once (each)'

    # Lint before and after the Rack middleware being tested.
    def stacked_lint(app)
      Rack::Lint.new(lambda do |env|
        Rack::Lint.new(app).call(env).tap {|response| response[2] = yield response[2]}
      end)
    end

    yielder_app = lambda do |_|
      input = Object.new
      def input.each; 10.times {yield 'foo'}; end
      [200, {"content-type" => "text/plain", "content-length" => "30"}, input]
    end

    lambda {
      body = stacked_lint(yielder_app) {|body|
        new_body = Struct.new(:body) do
          def each(&block)
            body.each { |part| yield part.upcase }
            body.close
          end
        end
        new_body.new(body)
      }.call(env({}))[2]
      body.each {|part| part.must_equal 'FOO'}
      body.close
    }.call

    lambda {
      body = stacked_lint(yielder_app) { |body|
        body.enum_for.to_a
      }.call(env({}))[2]
      body.each {}
      body.close
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/Middleware must not call #each directly/)

    lambda {
      body = stacked_lint(yielder_app) { |body|
        new_body = Struct.new(:body) do
          def each(&block)
            body.enum_for.each_slice(2) { |parts| yield parts.join }
          end
        end
        new_body.new(body)
      }.call(env({}))[2]
      body.each {}
      body.close
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/New body must yield at least once per iteration of old body/)

    lambda {
      body = stacked_lint(yielder_app) { |body|
        Struct.new(:body) do
          def each; body.each {|part| yield part} end
        end.new(body)
      }.call(env({}))[2]
      body.each {}
      body.close
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/Body has not been closed/)

    static_app = lambda do |_|
      input = ['foo'] * 10
      [200, {"content-type" => "text/plain", "content-length" => "30"}, input]
    end

    lambda {
      body = stacked_lint(static_app) { |body| body.to_ary}.call(env({}))[2]
      body.each {}
      body.close
    }.call

    array_mismatch = lambda do |_|
      input = Object.new
      def input.to_ary; ['bar'] * 10; end
      def input.each; 10.times {yield 'foo'}; end
      [200, {"content-type" => "text/plain", "content-length" => "30"}, input]
    end

    lambda {
      body = stacked_lint(array_mismatch) { |body| body.to_ary}.call(env({}))[2]
      body.each {}
      body.close
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/#to_ary not identical to contents produced by calling #each/)

    lambda {
      body = Rack::Lint.new(lambda { |env|
                               to_path = Object.new
                               def to_path.each; end
                               def to_path.to_path; 'non-existent' end
                               [200, { "content-type" => "text/plain", "content-length" => "0" }, to_path]
                             }).call(env({}))[2]
      body.each { |part| }
    }.must_raise(Rack::Lint::LintError).
      message.must_equal 'The file identified by body.to_path does not exist'

    lambda {
      body = Rack::Lint.new(lambda { |env|
                               [200, { "content-type" => "text/plain", "content-length" => "0" }, Object.new]
                             }).call(env({}))[2]
      body.call(nil)
    }.must_raise(Rack::Lint::LintError).
      message.must_equal 'Streaming Body must respond to call'

    lambda {
      body = Rack::Lint.new(lambda { |env|
                               [200, { "content-type" => "text/plain", "content-length" => "0" }, proc{}]
                             }).call(env({}))[2]
      body.call(StringIO.new)
      body.call(nil)
    }.must_raise(Rack::Lint::LintError).
      message.must_equal 'Response body must only be invoked once (call)'

    lambda {
      body = Rack::Lint.new(lambda { |env|
                               [200, { "content-type" => "text/plain", "content-length" => "0" }, proc{}]
                             }).call(env({}))[2]
      body.call(nil)
    }.must_raise(Rack::Lint::LintError).
      message.must_equal 'Stream must respond to read'
  end

  it "notice input handling errors" do
    lambda {
      Rack::Lint.new(lambda { |env|
                       env["rack.input"].gets("\r\n")
                       [201, { "content-type" => "text/plain", "content-length" => "0" }, []]
                     }).call(env({}))
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/gets called with arguments/)

    lambda {
      Rack::Lint.new(lambda { |env|
                       env["rack.input"].gets
                       env["rack.input"].read(1, 2, 3)
                       [201, { "content-type" => "text/plain", "content-length" => "0" }, []]
                     }).call(env({}))
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/read called with too many arguments/)

    lambda {
      Rack::Lint.new(lambda { |env|
                       env["rack.input"].read("foo")
                       [201, { "content-type" => "text/plain", "content-length" => "0" }, []]
                     }).call(env({}))
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/read called with non-integer and non-nil length/)

    lambda {
      Rack::Lint.new(lambda { |env|
                       env["rack.input"].read(-1)
                       [201, { "content-type" => "text/plain", "content-length" => "0" }, []]
                     }).call(env({}))
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/read called with a negative length/)

    lambda {
      Rack::Lint.new(lambda { |env|
                       env["rack.input"].read(nil, nil)
                       [201, { "content-type" => "text/plain", "content-length" => "0" }, []]
                     }).call(env({}))
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/read called with non-String buffer/)

    lambda {
      Rack::Lint.new(lambda { |env|
                       env["rack.input"].read(nil, 1)
                       [201, { "content-type" => "text/plain", "content-length" => "0" }, []]
                     }).call(env({}))
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/read called with non-String buffer/)

    weirdio = Object.new
    class << weirdio
      def gets
        42
      end

      def read
        23
      end

      def each
        yield 23
        yield 42
      end
    end

    eof_weirdio = Object.new
    class << eof_weirdio
      def gets
        nil
      end

      def read(*args)
        nil
      end

      def each
      end
    end

    lambda {
      Rack::Lint.new(lambda { |env|
                       env["rack.input"].gets
                       [201, { "content-type" => "text/plain", "content-length" => "0" }, []]
                     }).call(env("rack.input" => weirdio))
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/gets didn't return a String/)

    lambda {
      Rack::Lint.new(lambda { |env|
                       env["rack.input"].each(1) { |x| }
                       [201, { "content-type" => "text/plain", "content-length" => "0" }, []]
                     }).call(env("rack.input" => weirdio))
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/rack.input#each called with arguments/)

    lambda {
      Rack::Lint.new(lambda { |env|
                       env["rack.input"].each { |x| }
                       [201, { "content-type" => "text/plain", "content-length" => "0" }, []]
                     }).call(env("rack.input" => weirdio))
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/each didn't yield a String/)

    lambda {
      Rack::Lint.new(lambda { |env|
                       env["rack.input"].read
                       [201, { "content-type" => "text/plain", "content-length" => "0" }, []]
                     }).call(env("rack.input" => weirdio))
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/read didn't return nil or a String/)

    lambda {
      Rack::Lint.new(lambda { |env|
                       env["rack.input"].read
                       [201, { "content-type" => "text/plain", "content-length" => "0" }, []]
                     }).call(env("rack.input" => eof_weirdio))
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/read\(nil\) returned nil on EOF/)
  end

  it "can call close" do
    app = lambda do |env|
      env["rack.input"].close
      [201, {"content-type" => "text/plain", "content-length" => "0"}, []]
    end

    response = Rack::Lint.new(app).call(env({}))

    response.first.must_equal 201
  end

  it "notice error handling errors" do
    lambda {
      Rack::Lint.new(lambda { |env|
                       env["rack.errors"].write(42)
                       [201, { "content-type" => "text/plain", "content-length" => "0" }, []]
                     }).call(env({}))
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/write not called with a String/)

    lambda {
      Rack::Lint.new(lambda { |env|
                       env["rack.errors"].close
                       [201, { "content-type" => "text/plain", "content-length" => "0" }, []]
                     }).call(env({}))
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/close must not be called/)
  end

  it "notice HEAD errors" do
    Rack::Lint.new(lambda { |env|
                     [200, { "content-type" => "test/plain", "content-length" => "3" }, []]
                   }).call(env({ "REQUEST_METHOD" => "HEAD" })).first.must_equal 200

    lambda {
      Rack::Lint.new(lambda { |env|
                       [200, { "content-type" => "test/plain", "content-length" => "3" }, ["foo"]]
                     }).call(env({ "REQUEST_METHOD" => "HEAD" }))[2].each { }
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/body was given for HEAD/)
  end

  def assert_lint(*args)
    hello_str = "hello world".dup
    hello_str.force_encoding(Encoding::ASCII_8BIT)

    Rack::Lint.new(lambda { |env|
                     env["rack.input"].send(:read, *args)
                     [201, { "content-type" => "text/plain", "content-length" => "0" }, []]
                   }).call(env({ "rack.input" => StringIO.new(hello_str) })).
      first.must_equal 201
  end

  it "pass valid read calls" do
    assert_lint
    assert_lint 0
    assert_lint 1
    assert_lint nil
    assert_lint nil, ''.dup
    assert_lint 1, ''.dup
  end

  it "notices when request env doesn't have a valid rack.hijack callback" do
    lambda {
      Rack::Lint.new(lambda { |env|
                       env['rack.hijack'].call
                       [201, { "content-type" => "text/plain", "content-length" => "0" }, []]
                     }).call(env({ 'rack.hijack' => Object.new }))
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/rack.hijack must respond to call/)
  end

  it "notices when the response headers don't have a valid rack.hijack callback" do
    lambda {
      Rack::Lint.new(lambda { |env|
                       [201, { "content-type" => "text/plain", "content-length" => "0", 'rack.hijack' =>  Object.new }, []]
                     }).call(env({ 'rack.hijack?' => true }))
    }.must_raise(Rack::Lint::LintError).
      message.must_equal 'rack.hijack header must respond to #call'
  end

  it "pass valid rack.response_finished" do
    callable_object = Class.new do
      def call(env, status, headers, error)
      end
    end.new

    Rack::Lint.new(lambda { |env|
                     [200, {}, ["foo"]]
                   }).call(env({ "rack.response_finished" => [-> (env) {}, lambda { |env| }, callable_object], "content-length" => "3" })).first.must_equal 200
  end
end
