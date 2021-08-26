# frozen_string_literal: true

require_relative 'helper'
require 'tempfile'

describe Rack::Lint do
  def env(*args)
    Rack::MockRequest.env_for("/", *args)
  end

  it "pass valid request" do
    Rack::Lint.new(lambda { |env|
                     [200, { "Content-type" => "test/plain", "Content-length" => "3" }, ["foo"]]
                   }).call(env({})).first.must_equal 200
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
      Rack::Lint.new(nil).call(env("rack.version" => "0.2"))
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/must be an Array/)

    lambda {
      Rack::Lint.new(nil).call(env("rack.url_scheme" => "gopher"))
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/url_scheme unknown/)

    lambda {
      Rack::Lint.new(nil).call(env("rack.session" => []))
    }.must_raise(Rack::Lint::LintError).
      message.must_equal "session [] must respond to store and []="

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

    lambda {
      Rack::Lint.new(nil).call(env("rack.multipart.buffer_size" => 0))
    }.must_raise(Rack::Lint::LintError).
      message.must_equal "rack.multipart.buffer_size must be an Integer > 0 if specified"

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
      Rack::Lint.new(nil).call(env("REQUEST_METHOD" => "FUCKUP?"))
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/REQUEST_METHOD/)

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
    lambda {
      io = StringIO.new('a')
      io.binmode
      Rack::Lint.new(lambda { |env|
                       env['rack.input'].each{ |x| }
                       [200, Object.new, []]
                     }).call(env({ "rack.input" => io }))
    }.must_raise(Rack::Lint::LintError).
      message.must_equal "headers object should respond to #each, but doesn't (got Object as headers)"

    lambda {
      Rack::Lint.new(lambda { |env|
                       [200, { true => false }, []]
                     }).call(env({}))
    }.must_raise(Rack::Lint::LintError).
      message.must_equal "header key must be a string, was TrueClass"

    lambda {
      Rack::Lint.new(lambda { |env|
                       [200, { "Status" => "404" }, []]
                     }).call(env({}))
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/must not contain Status/)

    # From RFC 7230:<F24><F25>
    # Most HTTP header field values are defined using common syntax
    # components (token, quoted-string, and comment) separated by
    # whitespace or specific delimiting characters.  Delimiters are chosen
    # from the set of US-ASCII visual characters not allowed in a token
    # (DQUOTE and "(),/:;<=>?@[\]{}").
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
    valid_headers = 0.upto(127).map(&:chr) - invalid_headers
    valid_headers.each do |valid_header|
      Rack::Lint.new(lambda { |env|
                       [200, { valid_header => "text/plain" }, []]
                     }).call(env({})).first.must_equal 200
    end

    lambda {
      Rack::Lint.new(lambda { |env|
                       [200, { "Foo" => Object.new }, []]
                     }).call(env({}))
    }.must_raise(Rack::Lint::LintError).
      message.must_equal "a header value must be a String, but the value of 'Foo' is a Object"

    lambda {
      Rack::Lint.new(lambda { |env|
                       [200, { "Foo" => [1, 2, 3] }, []]
                     }).call(env({}))
    }.must_raise(Rack::Lint::LintError).
      message.must_equal "a header value must be a String, but the value of 'Foo' is a Array"


    lambda {
      Rack::Lint.new(lambda { |env|
                       [200, { "Foo-Bar" => "text\000plain" }, []]
                     }).call(env({}))
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/invalid header/)

    # line ends (010).must_be :allowed in header values.?
    Rack::Lint.new(lambda { |env|
                     [200, { "Foo-Bar" => "one\ntwo\nthree", "Content-Length" => "0", "Content-Type" => "text/plain" }, []]
                   }).call(env({})).first.must_equal 200

    # non-Hash header responses.must_be :allowed?
    Rack::Lint.new(lambda { |env|
                     [200, [%w(Content-Type text/plain), %w(Content-Length 0)], []]
                   }).call(env({})).first.must_equal 200
  end

  it "notice content-type errors" do
    # lambda {
    #   Rack::Lint.new(lambda { |env|
    #                    [200, {"Content-length" => "0"}, []]
    #                  }).call(env({}))
    # }.must_raise(Rack::Lint::LintError).
    #   message.must_match(/No Content-Type/)

    [100, 101, 204, 304].each do |status|
      lambda {
        Rack::Lint.new(lambda { |env|
                         [status, { "Content-type" => "text/plain", "Content-length" => "0" }, []]
                       }).call(env({}))
      }.must_raise(Rack::Lint::LintError).
        message.must_match(/Content-Type header found/)
    end
  end

  it "notice content-length errors" do
    [100, 101, 204, 304].each do |status|
      lambda {
        Rack::Lint.new(lambda { |env|
                         [status, { "Content-length" => "0" }, []]
                       }).call(env({}))
      }.must_raise(Rack::Lint::LintError).
        message.must_match(/Content-Length header found/)
    end

    lambda {
      Rack::Lint.new(lambda { |env|
                       [200, { "Content-type" => "text/plain", "Content-Length" => "1" }, []]
                     }).call(env({}))[2].each { }
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/Content-Length header was 1, but should be 0/)
  end

  it "notice body errors" do
    lambda {
      body = Rack::Lint.new(lambda { |env|
                               [200, { "Content-type" => "text/plain", "Content-length" => "3" }, [1, 2, 3]]
                             }).call(env({}))[2]
      body.each { |part| }
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/yielded non-string/)

    # Lint before and after the Rack middleware being tested.
    def stacked_lint(app)
      Rack::Lint.new(lambda do |env|
        Rack::Lint.new(app).call(env).tap {|response| response[2] = yield response[2]}
      end)
    end

    yielder_app = lambda do |_|
      input = Object.new
      def input.each; 10.times {yield 'foo'}; end
      [200, {"Content-type" => "text/plain", "Content-length" => "30"}, input]
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
      [200, {"Content-type" => "text/plain", "Content-length" => "30"}, input]
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
      [200, {"Content-type" => "text/plain", "Content-length" => "30"}, input]
    end

    lambda {
      body = stacked_lint(array_mismatch) { |body| body.to_ary}.call(env({}))[2]
      body.each {}
      body.close
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/#to_ary not identical to contents produced by calling #each/)
  end

  it "notice input handling errors" do
    lambda {
      Rack::Lint.new(lambda { |env|
                       env["rack.input"].gets("\r\n")
                       [201, { "Content-type" => "text/plain", "Content-length" => "0" }, []]
                     }).call(env({}))
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/gets called with arguments/)

    lambda {
      Rack::Lint.new(lambda { |env|
                       env["rack.input"].gets
                       env["rack.input"].read(1, 2, 3)
                       [201, { "Content-type" => "text/plain", "Content-length" => "0" }, []]
                     }).call(env({}))
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/read called with too many arguments/)

    lambda {
      Rack::Lint.new(lambda { |env|
                       env["rack.input"].read("foo")
                       [201, { "Content-type" => "text/plain", "Content-length" => "0" }, []]
                     }).call(env({}))
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/read called with non-integer and non-nil length/)

    lambda {
      Rack::Lint.new(lambda { |env|
                       env["rack.input"].read(-1)
                       [201, { "Content-type" => "text/plain", "Content-length" => "0" }, []]
                     }).call(env({}))
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/read called with a negative length/)

    lambda {
      Rack::Lint.new(lambda { |env|
                       env["rack.input"].read(nil, nil)
                       [201, { "Content-type" => "text/plain", "Content-length" => "0" }, []]
                     }).call(env({}))
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/read called with non-String buffer/)

    lambda {
      Rack::Lint.new(lambda { |env|
                       env["rack.input"].read(nil, 1)
                       [201, { "Content-type" => "text/plain", "Content-length" => "0" }, []]
                     }).call(env({}))
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/read called with non-String buffer/)

    lambda {
      Rack::Lint.new(lambda { |env|
                       env["rack.input"].rewind(0)
                       [201, { "Content-type" => "text/plain", "Content-length" => "0" }, []]
                     }).call(env({}))
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/rewind called with arguments/)

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

      def rewind
        raise Errno::ESPIPE, "Errno::ESPIPE"
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

      def rewind
      end
    end

    lambda {
      Rack::Lint.new(lambda { |env|
                       env["rack.input"].gets
                       [201, { "Content-type" => "text/plain", "Content-length" => "0" }, []]
                     }).call(env("rack.input" => weirdio))
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/gets didn't return a String/)

    lambda {
      Rack::Lint.new(lambda { |env|
                       env["rack.input"].each { |x| }
                       [201, { "Content-type" => "text/plain", "Content-length" => "0" }, []]
                     }).call(env("rack.input" => weirdio))
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/each didn't yield a String/)

    lambda {
      Rack::Lint.new(lambda { |env|
                       env["rack.input"].read
                       [201, { "Content-type" => "text/plain", "Content-length" => "0" }, []]
                     }).call(env("rack.input" => weirdio))
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/read didn't return nil or a String/)

    lambda {
      Rack::Lint.new(lambda { |env|
                       env["rack.input"].read
                       [201, { "Content-type" => "text/plain", "Content-length" => "0" }, []]
                     }).call(env("rack.input" => eof_weirdio))
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/read\(nil\) returned nil on EOF/)

    lambda {
      Rack::Lint.new(lambda { |env|
                       env["rack.input"].rewind
                       [201, { "Content-type" => "text/plain", "Content-length" => "0" }, []]
                     }).call(env("rack.input" => weirdio))
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/rewind raised Errno::ESPIPE/)


    lambda {
      Rack::Lint.new(lambda { |env|
                       env["rack.input"].close
                       [201, { "Content-type" => "text/plain", "Content-length" => "0" }, []]
                     }).call(env({}))
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/close must not be called/)
  end

  it "notice error handling errors" do
    lambda {
      Rack::Lint.new(lambda { |env|
                       env["rack.errors"].write(42)
                       [201, { "Content-type" => "text/plain", "Content-length" => "0" }, []]
                     }).call(env({}))
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/write not called with a String/)

    lambda {
      Rack::Lint.new(lambda { |env|
                       env["rack.errors"].close
                       [201, { "Content-type" => "text/plain", "Content-length" => "0" }, []]
                     }).call(env({}))
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/close must not be called/)
  end

  it "notice HEAD errors" do
    Rack::Lint.new(lambda { |env|
                     [200, { "Content-type" => "test/plain", "Content-length" => "3" }, []]
                   }).call(env({ "REQUEST_METHOD" => "HEAD" })).first.must_equal 200

    lambda {
      Rack::Lint.new(lambda { |env|
                       [200, { "Content-type" => "test/plain", "Content-length" => "3" }, ["foo"]]
                     }).call(env({ "REQUEST_METHOD" => "HEAD" }))[2].each { }
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/body was given for HEAD/)
  end

  def assert_lint(*args)
    hello_str = "hello world".dup
    hello_str.force_encoding(Encoding::ASCII_8BIT)

    Rack::Lint.new(lambda { |env|
                     env["rack.input"].send(:read, *args)
                     [201, { "Content-type" => "text/plain", "Content-length" => "0" }, []]
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

  it "notice hijack errors" do
    lambda {
      Rack::Lint.new(lambda { |env|
                       env['rack.hijack'].call
                       [201, { "Content-type" => "text/plain", "Content-length" => "0" }, []]
                     }).call(env({ 'rack.hijack?' => true, 'rack.hijack' => lambda { Object.new } }))
    }.must_raise(Rack::Lint::LintError).
      message.must_match(/rack.hijack_io must respond to read/)

      Rack::Lint.new(lambda { |env|
                       env['rack.hijack'].call
                       [201, { "Content-type" => "text/plain", "Content-length" => "0" }, []]
                     }).call(env({ 'rack.hijack?' => true, 'rack.hijack' => lambda { StringIO.new }, 'rack.hijack_io' => StringIO.new })).
        first.must_equal 201

      Rack::Lint.new(lambda { |env|
                       env['rack.hijack?'] = true
                       [201, { "Content-type" => "text/plain", "Content-length" => "0", 'rack.hijack' => lambda {|io| io }, 'rack.hijack_io' => StringIO.new }, []]
                     }).call(env({}))[1]['rack.hijack'].call(StringIO.new).read.must_equal ''
  end

end

describe "Rack::Lint::InputWrapper" do
  it "delegate :rewind to underlying IO object" do
    io = StringIO.new("123")
    wrapper = Rack::Lint::InputWrapper.new(io)
    wrapper.read.must_equal "123"
    wrapper.read.must_equal ""
    wrapper.rewind
    wrapper.read.must_equal "123"
  end
end
