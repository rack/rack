# frozen_string_literal: true

require_relative 'helper'
require 'yaml'
require_relative 'psych_fix'

separate_testing do
  require_relative '../lib/rack/mock_request'
  require_relative '../lib/rack/lint'
  require_relative '../lib/rack/request'
  require_relative '../lib/rack/body_proxy'
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

describe Rack::MockRequest do
  it "return a MockResponse" do
    res = Rack::MockRequest.new(app).get("")
    res.must_be_kind_of Rack::MockResponse
  end

  it "be able to only return the environment" do
    env = Rack::MockRequest.env_for("")
    env.must_be_kind_of Hash
  end

  it "should handle a non-GET request with :input String and :params" do
    env = Rack::MockRequest.env_for("/", method: :post, input: "", params: {})
    env["PATH_INFO"].must_equal "/"
    env.must_be_kind_of Hash
    env['rack.input'].read.must_equal ''
  end

  it "should convert :input IO object to binary encoding" do
    begin
      f = File.open(__FILE__, :encoding=>'UTF-8')
      env = Rack::MockRequest.env_for("/", method: :post, input: f)
      f.external_encoding.must_equal Encoding::BINARY
      env['rack.input'].read.must_equal File.binread(__FILE__)
    ensure
      f&.close
    end
  end

  it "should handle :input object that does not respond to set_encoding" do
    f = Object.new
    f.define_singleton_method(:read) { File.binread(__FILE__) }
    env = Rack::MockRequest.env_for("/", method: :post, input: f)
    env['rack.input'].read.must_equal File.binread(__FILE__)
  end

  it "return an environment with a path" do
    env = Rack::MockRequest.env_for("http://www.example.com/parse?location[]=1&location[]=2&age_group[]=2")
    env["QUERY_STRING"].must_equal "location[]=1&location[]=2&age_group[]=2"
    env["PATH_INFO"].must_equal "/parse"
    env.must_be_kind_of Hash
  end

  it "provide sensible defaults" do
    res = Rack::MockRequest.new(app).request

    env = YAML.unsafe_load(res.body)
    env["REQUEST_METHOD"].must_equal "GET"
    env["SERVER_NAME"].must_equal "example.org"
    env["SERVER_PORT"].must_equal "80"
    env["SERVER_PROTOCOL"].must_equal "HTTP/1.1"
    env["QUERY_STRING"].must_equal ""
    env["PATH_INFO"].must_equal "/"
    env["SCRIPT_NAME"].must_equal ""
    env["rack.url_scheme"].must_equal "http"
    env["mock.postdata"].must_be_nil
  end

  it "allow GET/POST/PUT/DELETE/HEAD" do
    res = Rack::MockRequest.new(app).get("", input: "foo")
    env = YAML.unsafe_load(res.body)
    env["REQUEST_METHOD"].must_equal "GET"

    res = Rack::MockRequest.new(app).post("", input: "foo")
    env = YAML.unsafe_load(res.body)
    env["REQUEST_METHOD"].must_equal "POST"

    res = Rack::MockRequest.new(app).put("", input: "foo")
    env = YAML.unsafe_load(res.body)
    env["REQUEST_METHOD"].must_equal "PUT"

    res = Rack::MockRequest.new(app).patch("", input: "foo")
    env = YAML.unsafe_load(res.body)
    env["REQUEST_METHOD"].must_equal "PATCH"

    res = Rack::MockRequest.new(app).delete("", input: "foo")
    env = YAML.unsafe_load(res.body)
    env["REQUEST_METHOD"].must_equal "DELETE"

    Rack::MockRequest.env_for("/", method: "HEAD")["REQUEST_METHOD"]
      .must_equal "HEAD"

    Rack::MockRequest.env_for("/", method: "OPTIONS")["REQUEST_METHOD"]
      .must_equal "OPTIONS"
  end

  it "set content length" do
    env = Rack::MockRequest.env_for("/", input: "foo")
    env["CONTENT_LENGTH"].must_equal "3"

    env = Rack::MockRequest.env_for("/", input: StringIO.new("foo"))
    env["CONTENT_LENGTH"].must_equal "3"

    env = Rack::MockRequest.env_for("/", input: Tempfile.new("name").tap { |t| t << "foo" })
    env["CONTENT_LENGTH"].must_equal "3"

    env = Rack::MockRequest.env_for("/", input: IO.pipe.first)
    env["CONTENT_LENGTH"].must_be_nil
  end

  it "allow posting" do
    res = Rack::MockRequest.new(app).get("", input: "foo")
    env = YAML.unsafe_load(res.body)
    env["mock.postdata"].must_equal "foo"

    res = Rack::MockRequest.new(app).post("", input: StringIO.new("foo".b))
    env = YAML.unsafe_load(res.body)
    env["mock.postdata"].must_equal "foo"
  end

  it "use all parts of an URL" do
    res = Rack::MockRequest.new(app).
      get("https://bla.example.org:9292/meh/foo?bar")
    res.must_be_kind_of Rack::MockResponse

    env = YAML.unsafe_load(res.body)
    env["REQUEST_METHOD"].must_equal "GET"
    env["SERVER_NAME"].must_equal "bla.example.org"
    env["SERVER_PORT"].must_equal "9292"
    env["QUERY_STRING"].must_equal "bar"
    env["PATH_INFO"].must_equal "/meh/foo"
    env["rack.url_scheme"].must_equal "https"
  end

  it "set SSL port and HTTP flag on when using https" do
    res = Rack::MockRequest.new(app).
      get("https://example.org/foo")
    res.must_be_kind_of Rack::MockResponse

    env = YAML.unsafe_load(res.body)
    env["REQUEST_METHOD"].must_equal "GET"
    env["SERVER_NAME"].must_equal "example.org"
    env["SERVER_PORT"].must_equal "443"
    env["QUERY_STRING"].must_equal ""
    env["PATH_INFO"].must_equal "/foo"
    env["rack.url_scheme"].must_equal "https"
    env["HTTPS"].must_equal "on"
  end

  it "prepend slash to uri path" do
    res = Rack::MockRequest.new(app).
      get("foo")
    res.must_be_kind_of Rack::MockResponse

    env = YAML.unsafe_load(res.body)
    env["REQUEST_METHOD"].must_equal "GET"
    env["SERVER_NAME"].must_equal "example.org"
    env["SERVER_PORT"].must_equal "80"
    env["QUERY_STRING"].must_equal ""
    env["PATH_INFO"].must_equal "/foo"
    env["rack.url_scheme"].must_equal "http"
  end

  it "properly convert method name to an uppercase string" do
    res = Rack::MockRequest.new(app).request(:get)
    env = YAML.unsafe_load(res.body)
    env["REQUEST_METHOD"].must_equal "GET"
  end

  it "accept :script_name option to set SCRIPT_NAME" do
    res = Rack::MockRequest.new(app).get("/", script_name: '/foo')
    env = YAML.unsafe_load(res.body)
    env["SCRIPT_NAME"].must_equal "/foo"
  end

  it "accept :http_version option to set SERVER_PROTOCOL" do
    res = Rack::MockRequest.new(app).get("/", http_version: 'HTTP/1.0')
    env = YAML.unsafe_load(res.body)
    env["SERVER_PROTOCOL"].must_equal "HTTP/1.0"
  end

  it "accept params and build query string for GET requests" do
    res = Rack::MockRequest.new(app).get("/foo?baz=2", params: { foo: { bar: "1" } })
    env = YAML.unsafe_load(res.body)
    env["REQUEST_METHOD"].must_equal "GET"
    env["QUERY_STRING"].must_include "baz=2"
    env["QUERY_STRING"].must_include "foo%5Bbar%5D=1"
    env["PATH_INFO"].must_equal "/foo"
    env["mock.postdata"].must_be_nil
  end

  it "accept raw input in params for GET requests" do
    res = Rack::MockRequest.new(app).get("/foo?baz=2", params: "foo%5Bbar%5D=1")
    env = YAML.unsafe_load(res.body)
    env["REQUEST_METHOD"].must_equal "GET"
    env["QUERY_STRING"].must_include "baz=2"
    env["QUERY_STRING"].must_include "foo%5Bbar%5D=1"
    env["PATH_INFO"].must_equal "/foo"
    env["mock.postdata"].must_be_nil
  end

  it "accept params and build url encoded params for POST requests" do
    res = Rack::MockRequest.new(app).post("/foo", params: { foo: { bar: "1" } })
    env = YAML.unsafe_load(res.body)
    env["REQUEST_METHOD"].must_equal "POST"
    env["QUERY_STRING"].must_equal ""
    env["PATH_INFO"].must_equal "/foo"
    env["CONTENT_TYPE"].must_equal "application/x-www-form-urlencoded"
    env["mock.postdata"].must_equal "foo%5Bbar%5D=1"
  end

  it "accept raw input in params for POST requests" do
    res = Rack::MockRequest.new(app).post("/foo", params: "foo%5Bbar%5D=1")
    env = YAML.unsafe_load(res.body)
    env["REQUEST_METHOD"].must_equal "POST"
    env["QUERY_STRING"].must_equal ""
    env["PATH_INFO"].must_equal "/foo"
    env["CONTENT_TYPE"].must_equal "application/x-www-form-urlencoded"
    env["mock.postdata"].must_equal "foo%5Bbar%5D=1"
  end

  it "accept params and build multipart encoded params for POST requests" do
    files = Rack::Multipart::UploadedFile.new(File.join(File.dirname(__FILE__), "multipart", "file1.txt"))
    res = Rack::MockRequest.new(app).post("/foo", params: { "submit-name" => "Larry", "files" => files })
    env = YAML.unsafe_load(res.body)
    env["REQUEST_METHOD"].must_equal "POST"
    env["QUERY_STRING"].must_equal ""
    env["PATH_INFO"].must_equal "/foo"
    env["CONTENT_TYPE"].must_equal "multipart/form-data; boundary=AaB03x"
    # The gsub accounts for differences in YAMLs affect on the data.
    env["mock.postdata"].gsub("\r", "").length.must_equal 206
  end

  it "behave valid according to the Rack spec" do
    url = "https://bla.example.org:9292/meh/foo?bar"
    Rack::MockRequest.new(app).get(url, lint: true).
      must_be_kind_of Rack::MockResponse
  end

  it "call close on the original body object" do
    called = false
    body   = Rack::BodyProxy.new(['hi']) { called = true }
    capp   = proc { |e| [200, { 'content-type' => 'text/plain' }, body] }
    called.must_equal false
    Rack::MockRequest.new(capp).get('/', lint: true)
    called.must_equal true
  end

  it "defaults encoding to ASCII 8BIT" do
    req = Rack::MockRequest.env_for("/foo")

    keys = [
      Rack::REQUEST_METHOD,
      Rack::SERVER_NAME,
      Rack::SERVER_PORT,
      Rack::QUERY_STRING,
      Rack::PATH_INFO,
      Rack::HTTPS,
      Rack::RACK_URL_SCHEME
    ]
    keys.each do |k|
      assert_equal Encoding::ASCII_8BIT, req[k].encoding
    end
  end
end
