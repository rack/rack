# frozen_string_literal: true

require_relative 'helper'

separate_testing do
  require_relative '../lib/rack/response'
end

describe Rack::Response do
  it 'has standard constructor' do
    headers = { "header" => "value" }
    body = ["body"]

    response = Rack::Response[200, headers, body]

    response.status.must_equal 200
    response.headers.must_equal headers
    response.body.must_equal body
  end

  it 'raises ArgumentError unless headers is a hash' do
    lambda {
      Rack::Response.new(nil, 200, Object.new)
    }.must_raise(ArgumentError)
  end

  it 'has cache-control methods' do
    response = Rack::Response.new
    cc = 'foo'
    response.cache_control = cc
    assert_equal cc, response.cache_control
    assert_equal cc, response.to_a[1]['cache-control']
  end

  it 'has an etag method' do
    response = Rack::Response.new
    etag = 'foo'
    response.etag = etag
    assert_equal etag, response.etag
    assert_equal etag, response.to_a[1]['etag']
  end

  it 'has a content-type method' do
    response = Rack::Response.new
    content_type = 'foo'
    response.content_type = content_type
    assert_equal content_type, response.content_type
    assert_equal content_type, response.to_a[1]['content-type']
  end

  it "have sensible default values" do
    response = Rack::Response.new
    status, header, body = response.finish
    status.must_equal 200
    header.must_equal({})
    response.each { |part|
      part.must_equal ""
    }

    response = Rack::Response.new
    status, header, body = *response
    status.must_equal 200
    header.must_equal({})
    body.each { |part|
      part.must_equal ""
    }
  end

  it "can be written to inside finish block and it does not generate a content-length header" do
    response = Rack::Response.new('foo')
    response.write "bar"

    _, h, body = response.finish do
      response.write "baz"
    end

    parts = []
    body.each { |part| parts << part }

    parts.must_equal ["foo", "bar", "baz"]
    h['content-length'].must_be_nil
  end

  it "#write calls #<< on non-iterable body" do
    content = []
    body = proc{|x| content << x}
    body.singleton_class.class_eval{alias << call}
    response = Rack::Response.new(body)
    response.write "bar"
    content.must_equal ["bar"]
  end

  it "can set and read headers" do
    response = Rack::Response.new
    response["content-type"].must_be_nil
    response["content-type"] = "text/plain"
    response["content-type"].must_equal "text/plain"
  end

  it "doesn't mutate given headers" do
    headers = {}.freeze

    response = Rack::Response.new([], 200, headers)
    response.headers["content-type"] = "text/plain"
    response.headers["content-type"].must_equal "text/plain"

    headers.wont_include("content-type")
  end

  it "can override the initial content-type with a different case" do
    response = Rack::Response.new("", 200, "content-type" => "text/plain")
    response["content-type"].must_equal "text/plain"
  end

  it "can get and set set-cookie header" do
    response = Rack::Response.new
    response.set_cookie_header.must_be_nil
    response.set_cookie_header = 'v=1;'
    response.set_cookie_header.must_equal 'v=1;'
    response.headers['set-cookie'].must_equal 'v=1;'
  end

  it "can set cookies" do
    response = Rack::Response.new

    response.set_cookie "foo", "bar"
    response["set-cookie"].must_equal "foo=bar"
    response.set_cookie "foo2", "bar2"
    response["set-cookie"].must_equal ["foo=bar", "foo2=bar2"]
    response.set_cookie "foo3", "bar3"
    response["set-cookie"].must_equal ["foo=bar", "foo2=bar2", "foo3=bar3"]
  end

  it "can set cookies with the same name for multiple domains" do
    response = Rack::Response.new
    response.set_cookie "foo", { value: "bar", domain: "sample.example.com" }
    response.set_cookie "foo", { value: "bar", domain: ".example.com" }
    response["set-cookie"].must_equal ["foo=bar; domain=sample.example.com", "foo=bar; domain=.example.com"]
  end

  it "formats the Cookie expiration date accordingly to RFC 6265" do
    response = Rack::Response.new

    response.set_cookie "foo", { value: "bar", expires: Time.now + 10 }
    response["set-cookie"].must_match(
      /expires=..., \d\d ... \d\d\d\d \d\d:\d\d:\d\d .../)
  end

  it "can set secure cookies" do
    response = Rack::Response.new
    response.set_cookie "foo", { value: "bar", secure: true }
    response["set-cookie"].must_equal "foo=bar; secure"
  end

  it "can set http only cookies" do
    response = Rack::Response.new
    response.set_cookie "foo", { value: "bar", httponly: true }
    response["set-cookie"].must_equal "foo=bar; httponly"
  end

  it "can set http only cookies with :http_only" do
    response = Rack::Response.new
    response.set_cookie "foo", { value: "bar", http_only: true }
    response["set-cookie"].must_equal "foo=bar; httponly"
  end

  it "can set prefers :httponly for http only cookie setting when :httponly and :http_only provided" do
    response = Rack::Response.new
    response.set_cookie "foo", { value: "bar", httponly: false, http_only: true }
    response["set-cookie"].must_equal "foo=bar"
  end

  it "can set same site cookies with symbol value :none" do
    response = Rack::Response.new
    response.set_cookie "foo", { value: "bar", same_site: :none }
    response["set-cookie"].must_equal "foo=bar; samesite=none"
  end

  it "can set same site cookies with symbol value :None" do
    response = Rack::Response.new
    response.set_cookie "foo", { value: "bar", same_site: :None }
    response["set-cookie"].must_equal "foo=bar; samesite=none"
  end

  it "can set same site cookies with string value 'None'" do
    response = Rack::Response.new
    response.set_cookie "foo", { value: "bar", same_site: "None" }
    response["set-cookie"].must_equal "foo=bar; samesite=none"
  end

  it "can set same site cookies with symbol value :lax" do
    response = Rack::Response.new
    response.set_cookie "foo", { value: "bar", same_site: :lax }
    response["set-cookie"].must_equal "foo=bar; samesite=lax"
  end

  it "can set same site cookies with symbol value :Lax" do
    response = Rack::Response.new
    response.set_cookie "foo", { value: "bar", same_site: :lax }
    response["set-cookie"].must_equal "foo=bar; samesite=lax"
  end

  it "can set same site cookies with string value 'Lax'" do
    response = Rack::Response.new
    response.set_cookie "foo", { value: "bar", same_site: "Lax" }
    response["set-cookie"].must_equal "foo=bar; samesite=lax"
  end

  it "can set same site cookies with boolean value true" do
    response = Rack::Response.new
    response.set_cookie "foo", { value: "bar", same_site: true }
    response["set-cookie"].must_equal "foo=bar; samesite=strict"
  end

  it "can set same site cookies with symbol value :strict" do
    response = Rack::Response.new
    response.set_cookie "foo", { value: "bar", same_site: :strict }
    response["set-cookie"].must_equal "foo=bar; samesite=strict"
  end

  it "can set same site cookies with symbol value :Strict" do
    response = Rack::Response.new
    response.set_cookie "foo", { value: "bar", same_site: :Strict }
    response["set-cookie"].must_equal "foo=bar; samesite=strict"
  end

  it "can set same site cookies with string value 'Strict'" do
    response = Rack::Response.new
    response.set_cookie "foo", { value: "bar", same_site: "Strict" }
    response["set-cookie"].must_equal "foo=bar; samesite=strict"
  end

  it "validates the same site option value" do
    response = Rack::Response.new
    lambda {
      response.set_cookie "foo", { value: "bar", same_site: "Foo" }
    }.must_raise(ArgumentError).
      message.must_match(/Invalid :same_site value: "Foo"/)
  end

  it "can set same site cookies with symbol value" do
    response = Rack::Response.new
    response.set_cookie "foo", { value: "bar", same_site: :Strict }
    response["set-cookie"].must_equal "foo=bar; samesite=strict"
  end

  [ nil, false ].each do |non_truthy|
    it "omits same site attribute given a #{non_truthy.inspect} value" do
      response = Rack::Response.new
      response.set_cookie "foo", { value: "bar", same_site: non_truthy }
      response["set-cookie"].must_equal "foo=bar"
    end
  end

  it "can delete cookies" do
    response = Rack::Response.new
    response.set_cookie "foo", "bar"
    response.set_cookie "foo2", "bar2"
    response.delete_cookie "foo"
    response["set-cookie"].must_equal [
      "foo=bar",
      "foo2=bar2",
      "foo=; max-age=0; expires=Thu, 01 Jan 1970 00:00:00 GMT"
    ]
  end

  it "can delete cookies with the same name from multiple domains" do
    response = Rack::Response.new
    response.set_cookie "foo", { value: "bar", domain: "sample.example.com" }
    response.set_cookie "foo", { value: "bar", domain: ".example.com" }
    response["set-cookie"].must_equal [
      "foo=bar; domain=sample.example.com",
      "foo=bar; domain=.example.com"
    ]

    response.delete_cookie "foo", domain: ".example.com"
    response["set-cookie"].must_equal [
      "foo=bar; domain=sample.example.com",
      "foo=bar; domain=.example.com",
      "foo=; domain=.example.com; max-age=0; expires=Thu, 01 Jan 1970 00:00:00 GMT"
    ]

    response.delete_cookie "foo", domain: "sample.example.com"
    response["set-cookie"].must_equal [
      "foo=bar; domain=sample.example.com",
      "foo=bar; domain=.example.com",
      "foo=; domain=.example.com; max-age=0; expires=Thu, 01 Jan 1970 00:00:00 GMT",
      "foo=; domain=sample.example.com; max-age=0; expires=Thu, 01 Jan 1970 00:00:00 GMT"
    ]
  end

  it "only deletes cookies for the domain specified" do
    response = Rack::Response.new
    response.set_cookie "foo", { value: "bar", domain: "example.com.example.com" }
    response.set_cookie "foo", { value: "bar", domain: "example.com" }
    response["set-cookie"].must_equal [
      "foo=bar; domain=example.com.example.com",
      "foo=bar; domain=example.com"
    ]

    response.delete_cookie "foo", { domain: "example.com" }
    response["set-cookie"].must_equal [
      "foo=bar; domain=example.com.example.com",
      "foo=bar; domain=example.com",
      "foo=; domain=example.com; max-age=0; expires=Thu, 01 Jan 1970 00:00:00 GMT"
    ]

    response.delete_cookie "foo", { domain: "example.com.example.com" }
    response["set-cookie"].must_equal [
      "foo=bar; domain=example.com.example.com",
      "foo=bar; domain=example.com",
      "foo=; domain=example.com; max-age=0; expires=Thu, 01 Jan 1970 00:00:00 GMT",
      "foo=; domain=example.com.example.com; max-age=0; expires=Thu, 01 Jan 1970 00:00:00 GMT"
    ]
  end

  it "can delete cookies with the same name with different paths" do
    response = Rack::Response.new
    response.set_cookie "foo", { value: "bar", path: "/" }
    response.set_cookie "foo", { value: "bar", path: "/path" }

    response["set-cookie"].must_equal [
      "foo=bar; path=/",
      "foo=bar; path=/path"
    ]

    response.delete_cookie "foo", path: "/path"
    response["set-cookie"].must_equal [
      "foo=bar; path=/",
      "foo=bar; path=/path",
      "foo=; path=/path; max-age=0; expires=Thu, 01 Jan 1970 00:00:00 GMT"
    ]
  end

  it "only delete cookies with the path specified" do
    response = Rack::Response.new
    response.set_cookie "foo", value: "bar", path: "/a/b"
    response["set-cookie"].must_equal(
      "foo=bar; path=/a/b"
    )

    response.delete_cookie "foo", path: "/a"
    response["set-cookie"].must_equal [
      "foo=bar; path=/a/b",
      "foo=; path=/a; max-age=0; expires=Thu, 01 Jan 1970 00:00:00 GMT"
    ]
  end

  it "only delete cookies with the domain and path specified" do
    response = Rack::Response.new
    response.delete_cookie "foo", path: "/a", domain: "example.com"
    response["set-cookie"].must_equal(
      "foo=; domain=example.com; path=/a; max-age=0; expires=Thu, 01 Jan 1970 00:00:00 GMT",
    )

    response.delete_cookie "foo", path: "/a/b", domain: "example.com"
    response["set-cookie"].must_equal [
      "foo=; domain=example.com; path=/a; max-age=0; expires=Thu, 01 Jan 1970 00:00:00 GMT",
      "foo=; domain=example.com; path=/a/b; max-age=0; expires=Thu, 01 Jan 1970 00:00:00 GMT",
    ]
  end

  it "can do redirects" do
    response = Rack::Response.new
    response.redirect "/foo"
    status, header = response.finish
    status.must_equal 302
    header["location"].must_equal "/foo"

    response = Rack::Response.new
    response.redirect "/foo", 307
    status, = response.finish

    status.must_equal 307
  end

  it "has a useful constructor" do
    r = Rack::Response.new("foo")
    body = r.finish[2]
    str = "".dup; body.each { |part| str << part }
    str.must_equal "foo"

    r = Rack::Response.new(["foo", "bar"])
    body = r.finish[2]
    str = "".dup; body.each { |part| str << part }
    str.must_equal "foobar"

    object_with_each = Object.new
    def object_with_each.each
      yield "foo"
      yield "bar"
    end
    r = Rack::Response.new(object_with_each)
    r.write "foo"
    body = r.finish[2]
    str = "".dup; body.each { |part| str << part }
    str.must_equal "foobarfoo"

    r = Rack::Response.new([], 500)
    r.status.must_equal 500

    r = Rack::Response.new([], "200 OK")
    r.status.must_equal 200
  end

  it "has a constructor that can take a block" do
    r = Rack::Response.new { |res|
      res.status = 404
      res.write "foo"
    }
    status, _, body = r.finish
    str = "".dup; body.each { |part| str << part }
    str.must_equal "foo"
    status.must_equal 404
  end

  it "correctly updates content-length when writing when initialized without body" do
    r = Rack::Response.new
    r.write('foo')
    r.write('bar')
    r.write('baz')
    _, header, body = r.finish
    str = "".dup; body.each { |part| str << part }
    str.must_equal "foobarbaz"
    header['content-length'].must_equal '9'
  end

  it "correctly updates content-length when writing when initialized with Array body" do
    r = Rack::Response.new(["foo"])
    r.write('bar')
    r.write('baz')
    _, header, body = r.finish
    str = "".dup; body.each { |part| str << part }
    str.must_equal "foobarbaz"
    header['content-length'].must_equal '9'
  end

  it "correctly updates content-length when writing when initialized with String body" do
    r = Rack::Response.new("foo")
    r.write('bar')
    r.write('baz')
    _, header, body = r.finish
    str = "".dup; body.each { |part| str << part }
    str.must_equal "foobarbaz"
    header['content-length'].must_equal '9'
  end

  it "correctly updates content-length when writing when initialized with object body that responds to #each" do
    obj = Object.new
    def obj.each
      yield 'foo'
      yield 'bar'
    end
    r = Rack::Response.new(obj)
    r.write('baz')
    r.write('baz')
    _, header, body = r.finish
    str = "".dup; body.each { |part| str << part }
    str.must_equal "foobarbazbaz"
    header['content-length'].must_equal '12'
  end

  it "doesn't return invalid responses" do
    r = Rack::Response.new(["foo", "bar"], 204)
    _, header, body = r.finish
    str = "".dup; body.each { |part| str << part }
    str.must_be :empty?
    header["content-type"].must_be_nil
    header['content-length'].must_be_nil

    lambda {
      Rack::Response.new(Object.new).each{}
    }.must_raise(NoMethodError).
      message.must_match(/undefined method .each. for/)
  end

  it "knows if it's empty" do
    r = Rack::Response.new
    r.must_be :empty?
    r.write "foo"
    r.wont_be :empty?

    r = Rack::Response.new
    r.must_be :empty?
    r.finish
    r.must_be :empty?

    r = Rack::Response.new
    r.must_be :empty?
    r.finish { }
    r.wont_be :empty?
  end

  it "provide access to the HTTP status" do
    res = Rack::Response.new
    res.status = 200
    res.must_be :successful?
    res.must_be :ok?

    res.status = 201
    res.must_be :successful?
    res.must_be :created?

    res.status = 202
    res.must_be :successful?
    res.must_be :accepted?

    res.status = 204
    res.must_be :successful?
    res.must_be :no_content?

    res.status = 301
    res.must_be :redirect?
    res.must_be :moved_permanently?

    res.status = 302
    res.must_be :redirect?

    res.status = 303
    res.must_be :redirect?

    res.status = 307
    res.must_be :redirect?

    res.status = 308
    res.must_be :redirect?

    res.status = 400
    res.wont_be :successful?
    res.must_be :client_error?
    res.must_be :bad_request?

    res.status = 401
    res.wont_be :successful?
    res.must_be :client_error?
    res.must_be :unauthorized?

    res.status = 404
    res.wont_be :successful?
    res.must_be :client_error?
    res.must_be :not_found?

    res.status = 405
    res.wont_be :successful?
    res.must_be :client_error?
    res.must_be :method_not_allowed?

    res.status = 406
    res.wont_be :successful?
    res.must_be :client_error?
    res.must_be :not_acceptable?

    res.status = 408
    res.wont_be :successful?
    res.must_be :client_error?
    res.must_be :request_timeout?

    res.status = 412
    res.wont_be :successful?
    res.must_be :client_error?
    res.must_be :precondition_failed?

    res.status = 422
    res.wont_be :successful?
    res.must_be :client_error?
    res.must_be :unprocessable?

    res.status = 501
    res.wont_be :successful?
    res.must_be :server_error?
  end

  it "provide access to the HTTP headers" do
    res = Rack::Response.new
    res["content-type"] = "text/yaml; charset=UTF-8"

    res.must_include "content-type"
    res.headers["content-type"].must_equal "text/yaml; charset=UTF-8"
    res["content-type"].must_equal "text/yaml; charset=UTF-8"
    res.content_type.must_equal "text/yaml; charset=UTF-8"
    res.media_type.must_equal "text/yaml"
    res.media_type_params.must_equal "charset" => "UTF-8"
    res.content_length.must_be_nil
    res.location.must_be_nil
  end

  it "does not add or change content-length when #finish()ing" do
    res = Rack::Response.new
    res.status = 200
    res.finish
    res.headers["content-length"].must_be_nil

    res = Rack::Response.new
    res.status = 200
    res.headers["content-length"] = "10"
    res.finish
    # We don't overwrite the content-length if it's already set - e.g. HEAD response may not have a body...
    res.headers["content-length"].must_equal "10"
  end

  it "updates length when body appended to using #write" do
    res = Rack::Response.new
    res.status = 200
    res.length.must_be_nil
    res.write "Hi"
    res.length.must_equal 2
    res.write " there"
    res.length.must_equal 8
    res.finish
    res.headers["content-length"].must_equal "8"
  end

  it "does not wrap body" do
    body = Object.new
    res = Rack::Response.new(body)

    # It was passed through unchanged:
    res.finish.last.must_equal body
  end

  it "does wraps body when using #write" do
    body = ["Foo"]
    res = Rack::Response.new(body)

    # Write something using the response object:
    res.write("Bar")

    # The original body was not modified:
    body.must_equal ["Foo"]

    # But a new buffered body was created:
    res.finish.last.must_equal ["Foo", "Bar"]
  end

  it "handles string reuse in existing body when calling #write" do
    body_class = Class.new do
      def initialize(file)
        @file = file
      end

      def each
        buffer = String.new

        while @file.read(5, buffer)
          yield(buffer)
        end
      end
    end
    body = body_class.new(StringIO.new('Large large file content'))
    res = Rack::Response.new(body)
    res.write(" written")
    res.finish.last.must_equal ["Large", " larg", "e fil", "e con", "tent", " written"]
  end

  it "calls close on #body" do
    res = Rack::Response.new
    res.body = StringIO.new
    res.close
    res.body.must_be :closed?
  end

  it "calls close on #body when 204 or 304" do
    res = Rack::Response.new
    res.body = StringIO.new
    res.finish
    res.body.wont_be :closed?

    res.status = 204
    _, _, b = res.finish
    res.body.must_be :closed?
    b.wont_equal res.body

    res.body = StringIO.new
    res.status = 304
    _, _, b = res.finish
    res.body.must_be :closed?
    b.wont_equal res.body
  end

  it "doesn't call close on #body when 205" do
    res = Rack::Response.new

    res.body = StringIO.new
    res.status = 205
    res.finish
    res.body.wont_be :closed?
  end

  it "doesn't clear #body when 101 and streaming" do
    res = Rack::Response.new

    streaming_body = proc{|stream| stream.close}
    res.body = streaming_body
    res.status = 101
    res.finish
    res.body.must_equal streaming_body
  end

  it "flatten doesn't cause infinite loop" do
    # https://github.com/rack/rack/issues/419
    res = Rack::Response.new("Hello World")

    res.finish.flatten.must_be_kind_of(Array)
  end

  it "should specify not to cache content" do
    response = Rack::Response.new

    response.cache!(1000)
    response.do_not_cache!

    expect(response['cache-control']).must_equal "no-cache, must-revalidate"

    expires_header = Time.parse(response['expires'])
    expect(expires_header).must_be :<=, Time.now
  end

  it "should not cache content if calling cache! after do_not_cache!" do
    response = Rack::Response.new

    response.do_not_cache!
    response.cache!(1000)

    expect(response['cache-control']).must_equal "no-cache, must-revalidate"

    expires_header = Time.parse(response['expires'])
    expect(expires_header).must_be :<=, Time.now
  end

  it "should specify to cache content" do
    response = Rack::Response.new

    duration = 120
    expires = Time.now + 100 # At least this far into the future
    response.cache!(duration)

    expect(response['cache-control']).must_equal "public, max-age=120"

    expires_header = Time.parse(response['expires'])
    expect(expires_header).must_be :>=, expires
  end
end

describe Rack::Response, 'headers' do
  before do
    @response = Rack::Response.new([], 200, { 'foo' => '1' })
  end

  it 'has_header?' do
    lambda { @response.has_header? nil }.must_raise ArgumentError

    @response.has_header?('foo').must_equal true
  end

  it 'get_header' do
    lambda { @response.get_header nil }.must_raise ArgumentError

    @response.get_header('foo').must_equal '1'
  end

  it 'set_header' do
    lambda { @response.set_header nil, '1' }.must_raise ArgumentError

    @response.set_header('foo', '2').must_equal '2'
    @response.has_header?('foo').must_equal true
    @response.get_header('foo').must_equal('2')

    @response.set_header('foo', nil).must_be_nil
    @response.get_header('foo').must_be_nil
  end

  it 'add_header' do
    lambda { @response.add_header nil, '1' }.must_raise ArgumentError

    # Add a value to an existing header
    @response.add_header('foo', '2').must_equal ["1", "2"]
    @response.get_header('foo').must_equal ["1", "2"]

    # Add nil to an existing header
    @response.add_header('foo', nil).must_equal ["1", "2"]
    @response.get_header('foo').must_equal ["1", "2"]

    # Add nil to a nonexistent header
    @response.add_header('bar', nil).must_be_nil
    @response.has_header?('bar').must_equal false
    @response.get_header('bar').must_be_nil

    # Add a value to a nonexistent header
    @response.add_header('bar', '1').must_equal '1'
    @response.has_header?('bar').must_equal true
    @response.get_header('bar').must_equal '1'
  end

  it 'delete_header' do
    lambda { @response.delete_header nil }.must_raise ArgumentError

    @response.delete_header('foo').must_equal '1'
    @response.has_header?('foo').must_equal false

    @response.delete_header('foo').must_be_nil
    @response.has_header?('foo').must_equal false

    @response.set_header('foo', 1)
    @response.delete_header('foo').must_equal 1
    @response.has_header?('foo').must_equal false
  end
end

describe Rack::Response::Raw do
  before do
    @response = Rack::Response::Raw.new(200, { 'foo' => '1' })
  end

  it 'has_header?' do
    @response.has_header?('foo').must_equal true
    @response.has_header?(nil).must_equal false
  end

  it 'get_header' do
    @response.get_header('foo').must_equal '1'
    @response.get_header(nil).must_be_nil
  end

  it 'set_header' do

    @response.set_header('foo', '2').must_equal '2'
    @response.has_header?('foo').must_equal true
    @response.get_header('foo').must_equal('2')

    @response.set_header(nil, '1').must_equal '1'
    @response.get_header(nil).must_equal '1'

    @response.set_header('foo', nil).must_be_nil
    @response.get_header('foo').must_be_nil
  end

  it 'delete_header' do
    @response.delete_header('foo').must_equal '1'
    @response.has_header?('foo').must_equal false

    @response.delete_header('foo').must_be_nil
    @response.has_header?('foo').must_equal false

    @response.set_header('foo', 1)
    @response.delete_header('foo').must_equal 1
    @response.has_header?('foo').must_equal false
  end
end
