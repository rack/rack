# frozen_string_literal: true

require_relative 'helper'
require 'yaml'
require_relative 'psych_fix'

separate_testing do
  require_relative '../lib/rack/mock_request'
  require_relative '../lib/rack/mock_response'
  require_relative '../lib/rack/lint'
  require_relative '../lib/rack/request'
end

app = Rack::Lint.new(lambda { |env|
  req = Rack::Request.new(env)

  if input = env["rack.input"]
    env["mock.postdata"] = input.read
  end

  if req.GET["error"]
    env["rack.errors"].puts req.GET["error"]
    env["rack.errors"].flush
  end

  body = req.head? ? "" : env.to_yaml
  response = Rack::Response.new(
    body,
    req.GET["status"] || 200,
    "content-type" => "text/yaml"
  )
  response.set_cookie("session_test", { value: "session_test", domain: "test.com", path: "/" })
  response.set_cookie("secure_test", { value: "secure_test", domain: "test.com",  path: "/", secure: true })
  response.set_cookie("persistent_test", { value: "persistent_test", max_age: 15552000, path: "/" })
  response.set_cookie("persistent_with_expires_test", { value: "persistent_with_expires_test", expires: Time.httpdate("Thu, 31 Oct 2021 07:28:00 GMT"), path: "/" })
  response.set_cookie("expires_and_max-age_test", { value: "expires_and_max-age_test", expires: Time.now + 15552000 * 2, max_age: 15552000, path: "/" })
  response.finish
})

describe Rack::MockResponse do
  it 'has standard constructor' do
    headers = { "header" => "value" }
    body = ["body"]

    response = Rack::MockResponse[200, headers, body]

    response.status.must_equal 200
    response.headers.must_equal headers
    response.body.must_equal body.join
  end

  it "provides access to the HTTP status" do
    res = Rack::MockRequest.new(app).get("")
    res.must_be :successful?
    res.must_be :ok?

    res = Rack::MockRequest.new(app).get("/?status=404")
    res.wont_be :successful?
    res.must_be :client_error?
    res.must_be :not_found?

    res = Rack::MockRequest.new(app).get("/?status=501")
    res.wont_be :successful?
    res.must_be :server_error?

    res = Rack::MockRequest.new(app).get("/?status=307")
    res.must_be :redirect?

    res = Rack::MockRequest.new(app).get("/?status=201", lint: true)
    res.must_be :empty?
  end

  it "provides access to the HTTP headers" do
    res = Rack::MockRequest.new(app).get("")
    res.must_include "content-type"
    res.headers["content-type"].must_equal "text/yaml"
    res.original_headers["content-type"].must_equal "text/yaml"
    res["content-type"].must_equal "text/yaml"
    res.content_type.must_equal "text/yaml"
    res.content_length.wont_equal 0
    res.location.must_be_nil
  end

  it "provides access to session cookies" do
    res = Rack::MockRequest.new(app).get("")
    session_cookie = res.cookie("session_test")
    session_cookie.value[0].must_equal "session_test"
    session_cookie.domain.must_equal "test.com"
    session_cookie.path.must_equal "/"
    session_cookie.secure.must_equal false
    session_cookie.expires.must_be_nil
  end

  it "provides access to persistent cookies set with max-age" do
    res = Rack::MockRequest.new(app).get("")
    persistent_cookie = res.cookie("persistent_test")
    persistent_cookie.value[0].must_equal "persistent_test"
    persistent_cookie.domain.must_be_nil
    persistent_cookie.path.must_equal "/"
    persistent_cookie.secure.must_equal false
    persistent_cookie.expires.wont_be_nil
    persistent_cookie.expires.must_be :<, (Time.now + 15552000)
  end

  it "provides access to persistent cookies set with expires" do
    res = Rack::MockRequest.new(app).get("")
    persistent_cookie = res.cookie("persistent_with_expires_test")
    persistent_cookie.value[0].must_equal "persistent_with_expires_test"
    persistent_cookie.domain.must_be_nil
    persistent_cookie.path.must_equal "/"
    persistent_cookie.secure.must_equal false
    persistent_cookie.expires.wont_be_nil
    persistent_cookie.expires.must_equal Time.httpdate("Thu, 31 Oct 2021 07:28:00 GMT")
  end

  it "parses cookies giving max-age precedence over expires" do
    res = Rack::MockRequest.new(app).get("")
    persistent_cookie = res.cookie("expires_and_max-age_test")
    persistent_cookie.value[0].must_equal "expires_and_max-age_test"
    persistent_cookie.expires.wont_be_nil
    persistent_cookie.expires.must_be :<, (Time.now + 15552000)
  end

  it "provides access to secure cookies" do
    res = Rack::MockRequest.new(app).get("")
    secure_cookie = res.cookie("secure_test")
    secure_cookie.value[0].must_equal "secure_test"
    secure_cookie.domain.must_equal "test.com"
    secure_cookie.path.must_equal "/"
    secure_cookie.secure.must_equal true
    secure_cookie.expires.must_be_nil
  end

  it "parses cookie headers with equals sign at the end" do
    res = Rack::MockRequest.new(->(env) { [200, { "Set-Cookie" => "__cf_bm=_somebase64encodedstringwithequalsatthened=; array=awesome" }, [""]] }).get("")
    cookie = res.cookie("__cf_bm")
    cookie.value[0].must_equal "_somebase64encodedstringwithequalsatthened="
  end

  it "returns nil if a non existent cookie is requested" do
    res = Rack::MockRequest.new(app).get("")
    res.cookie("i_dont_exist").must_be_nil
  end

  it "handles an empty cookie" do
    res = Rack::MockRequest.new(->(env) { [200, { "Set-Cookie" => "" }, [""]] }).get("")
    res.cookie("i_dont_exist").must_be_nil
  end

  it "parses multiple set-cookie headers provided as hash with array value" do
    cookie_headers = { "set-cookie" => ["array=awesome", "multiple=times"]}
    res = Rack::MockRequest.new(->(env) { [200, cookie_headers, [""]] }).get("")
    array_cookie = res.cookie("array")
    array_cookie.value[0].must_equal "awesome"
    second_cookie = res.cookie("multiple")
    second_cookie.value[0].must_equal "times"
  end

  it "provides access to the HTTP body" do
    res = Rack::MockRequest.new(app).get("")
    res.body.must_match(/rack/)
    assert_match(res, /rack/)

    res.match('rack')[0].must_equal 'rack'
    res.match('banana').must_be_nil
  end

  it "provides access to the Rack errors" do
    res = Rack::MockRequest.new(app).get("/?error=foo", lint: true)
    res.must_be :ok?
    res.errors.wont_be :empty?
    res.errors.must_include "foo"
  end

  it "allows calling body.close afterwards" do
    # this is exactly what rack-test does
    body = StringIO.new("hi")
    res = Rack::MockResponse.new(200, {}, body)
    body.close if body.respond_to?(:close)
    res.body.must_equal 'hi'
  end

  it "ignores plain strings passed as errors" do
    Rack::MockResponse.new(200, {}, [], 'e').errors.must_be_nil
  end

  it "optionally makes Rack errors fatal" do
    lambda {
      Rack::MockRequest.new(app).get("/?error=foo", fatal: true)
    }.must_raise Rack::MockRequest::FatalWarning

    lambda {
      Rack::MockRequest.new(lambda { |env| env['rack.errors'].write(env['rack.errors'].string) }).get("/", fatal: true)
    }.must_raise(Rack::MockRequest::FatalWarning).message.must_equal ''
  end

  class ChunkedBody # :nodoc:
    TERM = "\r\n"
    TAIL = "0#{TERM}"

    # Store the response body to be chunked.
    def initialize(body)
      @body = body
    end

    # For each element yielded by the response body, yield the element in chunked
    # encoding.
    def each(&block)
      term = TERM
      @body.each do |chunk|
        size = chunk.bytesize
        next if size == 0

        yield [size.to_s(16), term, chunk.b, term].join
      end
      yield TAIL
      yield term
    end

    # Close the response body if the response body supports it.
    def close
      @body.close if @body.respond_to?(:close)
    end
  end

  it "does not calculate content length for streaming body" do
    body = ChunkedBody.new(["a" * 96])
    res = Rack::MockResponse.new(200, { "transfer-encoding" => "chunked" }, body).to_a
    headers = res[1]
    refute headers.key?("content-length")
  end
end

describe Rack::MockResponse, 'headers' do
  before do
    @res = Rack::MockRequest.new(app).get('')
    @res.set_header 'FOO', '1'
  end

  it 'has_header?' do
    lambda { @res.has_header? nil }.must_raise ArgumentError

    @res.has_header?('FOO').must_equal true
    @res.has_header?('Foo').must_equal true
  end

  it 'get_header' do
    lambda { @res.get_header nil }.must_raise ArgumentError

    @res.get_header('FOO').must_equal '1'
    @res.get_header('Foo').must_equal '1'
  end

  it 'set_header' do
    lambda { @res.set_header nil, '1' }.must_raise ArgumentError

    @res.set_header('FOO', '2').must_equal '2'
    @res.get_header('FOO').must_equal '2'

    @res.set_header('Foo', '3').must_equal '3'
    @res.get_header('Foo').must_equal '3'
    @res.get_header('FOO').must_equal '3'

    @res.set_header('FOO', nil).must_be_nil
    @res.get_header('FOO').must_be_nil
    @res.has_header?('FOO').must_equal true
  end

  it 'add_header' do
    lambda { @res.add_header nil, '1' }.must_raise ArgumentError

    # Sets header on first addition
    @res.add_header('FOO', '1').must_equal ['1', '1']
    @res.get_header('FOO').must_equal ['1', '1']

    # Ignores nil additions
    @res.add_header('FOO', nil).must_equal ['1', '1']
    @res.get_header('FOO').must_equal ['1', '1']

    # Converts additions to strings
    @res.add_header('FOO', 2).must_equal ['1', '1', '2']
    @res.get_header('FOO').must_equal ['1', '1', '2']

    # Respects underlying case-sensitivity
    @res.add_header('Foo', 'yep').must_equal ['1', '1', '2', 'yep']
    @res.get_header('Foo').must_equal ['1', '1', '2', 'yep']
    @res.get_header('FOO').must_equal ['1', '1', '2', 'yep']
  end

  it 'delete_header' do
    lambda { @res.delete_header nil }.must_raise ArgumentError

    @res.delete_header('FOO').must_equal '1'
    @res.has_header?('FOO').must_equal false

    @res.has_header?('Foo').must_equal false
    @res.delete_header('Foo').must_be_nil
  end

  it 'does not add extra headers' do
    # Force the body to be "enumerable" only:
    enumerable_app = lambda { |env| [200, {}, [""].to_enum] }

    response = Rack::MockRequest.new(enumerable_app).get('/')
    response.status.must_equal 200
    # This fails in Rack < 3.1 as it incorrectly adds a content-length header:
    response.headers.must_equal({})
    response.body.must_equal ""
  end
end
