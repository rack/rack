# frozen_string_literal: true

require_relative 'helper'
require 'cgi'
require 'forwardable'
require 'securerandom'

separate_testing do
  require_relative '../lib/rack/request'
  require_relative '../lib/rack/mock_request'
  require_relative '../lib/rack/lint'
end

class RackRequestTest < Minitest::Spec
  it "copies the env when duping" do
    req = make_request(Rack::MockRequest.env_for("http://example.com:8080/"))

    if req.delegate?
      skip "delegate requests don't dup environments"
    end

    refute_same req.env, req.dup.env
  end

  it 'can check if something has been set' do
    req = make_request(Rack::MockRequest.env_for("http://example.com:8080/"))
    refute req.has_header?("FOO")
  end

  it "can get a key from the env" do
    req = make_request(Rack::MockRequest.env_for("http://example.com:8080/"))
    assert_equal "example.com", req.get_header("SERVER_NAME")
  end

  it 'can calculate the authority' do
    req = make_request(Rack::MockRequest.env_for("http://example.com:8080/"))
    assert_equal "example.com:8080", req.authority
  end

  it 'can calculate the authority without a port' do
    req = make_request(Rack::MockRequest.env_for("http://example.com/"))
    assert_equal "example.com:80", req.authority
  end

  it 'can calculate the authority without a port on ssl' do
    req = make_request(Rack::MockRequest.env_for("https://example.com/"))
    assert_equal "example.com:443", req.authority
  end

  it 'can calculate the server authority' do
    req = make_request('SERVER_NAME' => 'example.com')
    assert_equal "example.com", req.server_authority
    req = make_request('SERVER_NAME' => 'example.com', 'SERVER_PORT' => 8080)
    assert_equal "example.com:8080", req.server_authority
  end

  it 'can calculate the port without an authority' do
    req = make_request('SERVER_PORT' => 8080)
    assert_equal 8080, req.port
    req = make_request('HTTPS' => 'on')
    assert_equal 443, req.port
  end

  it 'yields to the block if no value has been set' do
    req = make_request(Rack::MockRequest.env_for("http://example.com:8080/"))
    yielded = false
    req.fetch_header("FOO") do
      yielded = true
      req.set_header "FOO", 'bar'
    end

    assert yielded
    assert_equal "bar", req.get_header("FOO")
  end

  it 'can iterate over values' do
    req = make_request(Rack::MockRequest.env_for("http://example.com:8080/"))
    req.set_header 'foo', 'bar'
    hash = {}
    req.each_header do |k, v|
      hash[k] = v
    end
    assert_equal 'bar', hash['foo']
  end

  it 'can set values in the env' do
    req = make_request(Rack::MockRequest.env_for("http://example.com:8080/"))
    req.set_header("FOO", "BAR")
    assert_equal "BAR", req.get_header("FOO")
  end

  it 'can add to multivalued headers in the env' do
    req = make_request(Rack::MockRequest.env_for('http://example.com:8080/'))

    assert_equal '1', req.add_header('FOO', '1')
    assert_equal '1', req.get_header('FOO')

    assert_equal '1,2', req.add_header('FOO', '2')
    assert_equal '1,2', req.get_header('FOO')

    assert_equal '1,2', req.add_header('FOO', nil)
    assert_equal '1,2', req.get_header('FOO')
  end

  it 'can delete env values' do
    req = make_request(Rack::MockRequest.env_for("http://example.com:8080/"))
    req.set_header 'foo', 'bar'
    assert req.has_header? 'foo'
    req.delete_header 'foo'
    refute req.has_header? 'foo'
  end

  it "wrap the rack variables" do
    req = make_request(Rack::MockRequest.env_for("http://example.com:8080/"))

    req.body.must_be_nil
    req.scheme.must_equal "http"
    req.request_method.must_equal "GET"

    req.must_be :get?
    req.wont_be :post?
    req.wont_be :put?
    req.wont_be :delete?
    req.wont_be :head?
    req.wont_be :patch?

    req.script_name.must_equal ""
    req.path_info.must_equal "/"
    req.query_string.must_equal ""

    req.host.must_equal "example.com"
    req.port.must_equal 8080

    req.content_length.must_be_nil
    req.content_type.must_be_nil
  end

  it "figure out the correct host" do
    req = make_request \
      Rack::MockRequest.env_for("/", "HTTP_HOST" => "www2.example.org")
    req.host.must_equal "www2.example.org"
    req.hostname.must_equal "www2.example.org"

    req = make_request \
      Rack::MockRequest.env_for("/", "HTTP_HOST" => "123foo.example.com")
    req.host.must_equal "123foo.example.com"
    req.hostname.must_equal "123foo.example.com"

    req = make_request \
      Rack::MockRequest.env_for("/", "HTTP_HOST" => "♡.com")
    req.host.must_equal "♡.com"
    req.hostname.must_equal "♡.com"

    req = make_request \
      Rack::MockRequest.env_for("/", "HTTP_HOST" => "♡.com:80")
    req.host.must_equal "♡.com"
    req.hostname.must_equal "♡.com"

    req = make_request \
      Rack::MockRequest.env_for("/", "HTTP_HOST" => "nic.谷歌")
    req.host.must_equal "nic.谷歌"
    req.hostname.must_equal "nic.谷歌"

    req = make_request \
      Rack::MockRequest.env_for("/", "HTTP_HOST" => "nic.谷歌:80")
    req.host.must_equal "nic.谷歌"
    req.hostname.must_equal "nic.谷歌"

    req = make_request \
      Rack::MockRequest.env_for("/", "HTTP_HOST" => "technically_invalid.example.com")
    req.host.must_equal "technically_invalid.example.com"
    req.hostname.must_equal "technically_invalid.example.com"

    req = make_request \
      Rack::MockRequest.env_for("/", "HTTP_HOST" => "technically_invalid.example.com:80")
    req.host.must_equal "technically_invalid.example.com"
    req.hostname.must_equal "technically_invalid.example.com"

    req = make_request \
      Rack::MockRequest.env_for("/", "HTTP_HOST" => "trailing_newline.com\n")
    req.host.must_be_nil
    req.hostname.must_be_nil

    req = make_request \
      Rack::MockRequest.env_for("/", "HTTP_HOST" => "really\nbad\ninput")
    req.host.must_be_nil
    req.hostname.must_be_nil

    req = make_request \
      Rack::MockRequest.env_for("/", "HTTP_HOST" => "some_service:3001")
    req.host.must_equal "some_service"
    req.hostname.must_equal "some_service"

    req = make_request \
      Rack::MockRequest.env_for("/", "SERVER_NAME" => "example.org", "SERVER_PORT" => "9292")
    req.host.must_equal "example.org"
    req.hostname.must_equal "example.org"

    req = make_request \
      Rack::MockRequest.env_for("/", "HTTP_HOST" => "localhost:81", "HTTP_FORWARDED" => "host=example.org:9292")
    req.host.must_equal "example.org"

    # Test obfuscated identifier: https://tools.ietf.org/html/rfc7239#section-6.3
    req = make_request \
      Rack::MockRequest.env_for("/", "HTTP_HOST" => "localhost:81", "HTTP_FORWARDED" => "host=ObFuScaTeD")
    req.host.must_equal "ObFuScaTeD"

    req = make_request \
      Rack::MockRequest.env_for("/", "HTTP_HOST" => "localhost:81", "HTTP_FORWARDED" => "host=example.com; host=example.org:9292")
    req.host.must_equal "example.org"

    req = make_request \
      Rack::MockRequest.env_for("/", "HTTP_HOST" => "localhost:81", "HTTP_X_FORWARDED_HOST" => "example.org:9292", "HTTP_FORWARDED" => "host=example.com")
    req.host.must_equal "example.com"

    req = make_request \
      Rack::MockRequest.env_for("/", "HTTP_HOST" => "localhost:81", "HTTP_X_FORWARDED_HOST" => "example.org:9292")
    req.host.must_equal "example.org"
    req.hostname.must_equal "example.org"

    req = make_request \
      Rack::MockRequest.env_for("/", "HTTP_HOST" => "localhost:81", "HTTP_X_FORWARDED_HOST" => "[2001:db8:cafe::17]:47011")
    req.host.must_equal "[2001:db8:cafe::17]"
    req.hostname.must_equal "2001:db8:cafe::17"

    req = make_request \
      Rack::MockRequest.env_for("/", "HTTP_HOST" => "localhost:81", "HTTP_X_FORWARDED_HOST" => "2001:db8:cafe::17")
    req.host.must_equal "[2001:db8:cafe::17]"
    req.hostname.must_equal "2001:db8:cafe::17"

    req = make_request \
      Rack::MockRequest.env_for("/", "HTTP_HOST" => "localhost:81", "HTTP_X_FORWARDED_HOST" => "[::]:47011")
    req.host.must_equal "[::]"
    req.hostname.must_equal "::"

    req = make_request \
      Rack::MockRequest.env_for("/", "HTTP_HOST" => "localhost:81", "HTTP_X_FORWARDED_HOST" => "[1111:2222:3333:4444:5555:6666:123.123.123.123]")
    req.host.must_equal "[1111:2222:3333:4444:5555:6666:123.123.123.123]"
    req.hostname.must_equal "1111:2222:3333:4444:5555:6666:123.123.123.123"

    req = make_request \
      Rack::MockRequest.env_for("/", "HTTP_HOST" => "localhost:81", "HTTP_X_FORWARDED_HOST" => "[1111:2222:3333:4444:5555:6666:123.123.123.123]:47011")
    req.host.must_equal "[1111:2222:3333:4444:5555:6666:123.123.123.123]"
    req.hostname.must_equal "1111:2222:3333:4444:5555:6666:123.123.123.123"

    req = make_request \
      Rack::MockRequest.env_for("/", "HTTP_HOST" => "localhost:81", "HTTP_X_FORWARDED_HOST" => "0.0.0.0")
    req.host.must_equal "0.0.0.0"
    req.hostname.must_equal "0.0.0.0"

    req = make_request \
      Rack::MockRequest.env_for("/", "HTTP_HOST" => "localhost:81", "HTTP_X_FORWARDED_HOST" => "0.0.0.0:47011")
    req.host.must_equal "0.0.0.0"
    req.hostname.must_equal "0.0.0.0"

    req = make_request \
      Rack::MockRequest.env_for("/", "HTTP_HOST" => "localhost:81", "HTTP_X_FORWARDED_HOST" => "255.255.255.255")
    req.host.must_equal "255.255.255.255"
    req.hostname.must_equal "255.255.255.255"

    req = make_request \
      Rack::MockRequest.env_for("/", "HTTP_HOST" => "localhost:81", "HTTP_X_FORWARDED_HOST" => "255.255.255.255:47011")
    req.host.must_equal "255.255.255.255"
    req.hostname.must_equal "255.255.255.255"

    req = make_request \
      Rack::MockRequest.env_for("/", "HTTP_HOST" => "really\nbad\ninput")
    req.host.must_be_nil
    req.hostname.must_be_nil

    req = make_request \
      Rack::MockRequest.env_for("/", "HTTP_HOST" => "localhost:81", "HTTP_X_FORWARDED_HOST" => "[0]")
    req.host.must_be_nil
    req.hostname.must_be_nil

    req = make_request \
      Rack::MockRequest.env_for("/", "HTTP_HOST" => "localhost:81", "HTTP_X_FORWARDED_HOST" => "[:::]")
    req.host.must_be_nil
    req.hostname.must_be_nil

    req = make_request \
      Rack::MockRequest.env_for("/", "HTTP_HOST" => "localhost:81", "HTTP_X_FORWARDED_HOST" => "[1111:2222:3333:4444:5555:6666:7777:88888]")
    req.host.must_be_nil
    req.hostname.must_be_nil

    req = make_request \
      Rack::MockRequest.env_for("/", "HTTP_HOST" => "localhost:81", "HTTP_X_FORWARDED_HOST" => "0.0..0.0")
    req.host.must_equal '0.0..0.0'
    req.hostname.must_equal '0.0..0.0'

    req = make_request \
      Rack::MockRequest.env_for("/", "HTTP_HOST" => "localhost:81", "HTTP_X_FORWARDED_HOST" => "255.255.255.0255")
    req.host.must_equal "255.255.255.0255"
    req.hostname.must_equal "255.255.255.0255"

    env = Rack::MockRequest.env_for("/")
    env.delete("SERVER_NAME")
    req = make_request(env)
    req.host.must_be_nil
  end

  it "figure out the correct port" do
    req = make_request \
      Rack::MockRequest.env_for("/", "HTTP_HOST" => "www2.example.org")
    req.port.must_equal 80

    req = make_request \
      Rack::MockRequest.env_for("/", "HTTP_HOST" => "www2.example.org:81")
    req.port.must_equal 81

    req = make_request \
      Rack::MockRequest.env_for("/", "HTTP_HOST" => "some_service:3001")
    req.port.must_equal 3001

    req = make_request \
      Rack::MockRequest.env_for("/", "SERVER_NAME" => "example.org", "SERVER_PORT" => "9292")
    req.port.must_equal 9292

    req = make_request \
      Rack::MockRequest.env_for("/", "HTTP_HOST" => "localhost:81", "HTTP_X_FORWARDED_HOST" => "example.org:9292")
    req.port.must_equal 9292

    req = make_request \
      Rack::MockRequest.env_for("/", "HTTP_HOST" => "localhost:81", "HTTP_X_FORWARDED_HOST" => "[2001:db8:cafe::17]:47011")
    req.port.must_equal 47011

    req = make_request \
      Rack::MockRequest.env_for("/", "HTTP_HOST" => "localhost:81", "HTTP_X_FORWARDED_HOST" => "2001:db8:cafe::17")
    req.port.must_equal 80

    req = make_request \
      Rack::MockRequest.env_for("/", "HTTP_HOST" => "localhost:81", "HTTP_X_FORWARDED_HOST" => "example.org")
    req.port.must_equal 80

    req = make_request \
      Rack::MockRequest.env_for("/", "HTTP_HOST" => "localhost:81", "HTTP_X_FORWARDED_HOST" => "example.org", "HTTP_X_FORWARDED_SSL" => "on")
    req.port.must_equal 443

    req = make_request \
      Rack::MockRequest.env_for("/", "HTTP_HOST" => "localhost:81", "HTTP_X_FORWARDED_HOST" => "example.org", "HTTP_X_FORWARDED_PROTO" => "https")
    req.port.must_equal 443

    req = make_request \
      Rack::MockRequest.env_for("/", "HTTP_HOST" => "localhost:81", "HTTP_X_FORWARDED_HOST" => "example.org", "HTTP_X_FORWARDED_PORT" => "9393")
    req.port.must_equal 9393

    req = make_request \
      Rack::MockRequest.env_for("/", "HTTP_HOST" => "localhost:81", "HTTP_X_FORWARDED_HOST" => "example.org:9393", "SERVER_PORT" => "80")
    req.port.must_equal 9393

    req = make_request \
      Rack::MockRequest.env_for("/", "HTTP_HOST" => "localhost:81", "HTTP_X_FORWARDED_HOST" => "example.org", "SERVER_PORT" => "9393")
    req.port.must_equal 80

    req = make_request \
      Rack::MockRequest.env_for("/", "HTTP_HOST" => "localhost", "HTTP_X_FORWARDED_PROTO" => "https", "SERVER_PORT" => "80")
    req.port.must_equal 443

    req = make_request \
      Rack::MockRequest.env_for("/", "HTTP_HOST" => "localhost", "HTTP_X_FORWARDED_PROTO" => "https,https", "SERVER_PORT" => "80")
    req.port.must_equal 443

    req = make_request \
      Rack::MockRequest.env_for("/", "HTTP_HOST" => "localhost", "HTTP_FORWARDED" => "proto=https", "HTTP_X_FORWARDED_PROTO" => "http", "SERVER_PORT" => "9393")
    req.port.must_equal 443
  end

  it "have forwarded_* methods respect forwarded_priority" do
    begin
      default_priority = Rack::Request.forwarded_priority
      default_proto_priority = Rack::Request.x_forwarded_proto_priority

      def self.req(headers)
        req = make_request Rack::MockRequest.env_for("/", headers)
        req.singleton_class.send(:public, :forwarded_scheme)
        req
      end

      req("HTTP_FORWARDED"=>"for=1.2.3.4",
        "HTTP_X_FORWARDED_FOR" => "2.3.4.5").
        forwarded_for.must_equal ['1.2.3.4']

      req("HTTP_FORWARDED"=>"for=1.2.3.4:1234",
        "HTTP_X_FORWARDED_PORT" => "2345").
        forwarded_port.must_equal [1234]

      req("HTTP_FORWARDED"=>"for=1.2.3.4",
        "HTTP_X_FORWARDED_PORT" => "2345").
        forwarded_port.must_equal []

      req("HTTP_FORWARDED"=>"host=1.2.3.4, host=3.4.5.6",
        "HTTP_X_FORWARDED_HOST" => "2.3.4.5,4.5.6.7").
        forwarded_authority.must_equal '3.4.5.6'

      req("HTTP_X_FORWARDED_PROTO" => "ws",
        "HTTP_X_FORWARDED_SCHEME" => "http").
        forwarded_scheme.must_equal "ws"

      req("HTTP_X_FORWARDED_SCHEME" => "http").
        forwarded_scheme.must_equal "http"

      Rack::Request.forwarded_priority = [nil, :x_forwarded, :forwarded]

      req("HTTP_FORWARDED"=>"for=1.2.3.4",
        "HTTP_X_FORWARDED_FOR" => "2.3.4.5").
        forwarded_for.must_equal ['2.3.4.5']

      req("HTTP_FORWARDED"=>"for=1.2.3.4",
        "HTTP_X_FORWARDED_PORT" => "2345").
        forwarded_port.must_equal [2345]

      req("HTTP_FORWARDED"=>"host=1.2.3.4, host=3.4.5.6",
        "HTTP_X_FORWARDED_HOST" => "2.3.4.5,4.5.6.7").
        forwarded_authority.must_equal '4.5.6.7'

      req("HTTP_FORWARDED"=>"proto=https",
        "HTTP_X_FORWARDED_PROTO" => "ws",
        "HTTP_X_FORWARDED_SCHEME" => "http").
        forwarded_scheme.must_equal "ws"

      req("HTTP_FORWARDED"=>"proto=https",
        "HTTP_X_FORWARDED_SCHEME" => "http").
        forwarded_scheme.must_equal "http"

      req("HTTP_FORWARDED"=>"proto=https").
        forwarded_scheme.must_equal "https"

      Rack::Request.x_forwarded_proto_priority = [nil, :scheme, :proto]

      req("HTTP_FORWARDED"=>"proto=https",
        "HTTP_X_FORWARDED_PROTO" => "ws",
        "HTTP_X_FORWARDED_SCHEME" => "http").
        forwarded_scheme.must_equal "http"

      req("HTTP_FORWARDED"=>"proto=https",
        "HTTP_X_FORWARDED_PROTO" => "ws").
        forwarded_scheme.must_equal "ws"

      req("HTTP_FORWARDED"=>"proto=https").
        forwarded_scheme.must_equal "https"

      Rack::Request.forwarded_priority = [:x_forwarded]

      req("HTTP_FORWARDED"=>"proto=https",
        "HTTP_X_FORWARDED_PROTO" => "ws",
        "HTTP_X_FORWARDED_SCHEME" => "http").
        forwarded_scheme.must_equal "http"

      req("HTTP_FORWARDED"=>"proto=https",
        "HTTP_X_FORWARDED_PROTO" => "ws").
        forwarded_scheme.must_equal "ws"

      req("HTTP_FORWARDED"=>"proto=https").
        forwarded_scheme.must_be_nil

      Rack::Request.x_forwarded_proto_priority = [:scheme]

      req("HTTP_FORWARDED"=>"proto=https",
        "HTTP_X_FORWARDED_PROTO" => "ws",
        "HTTP_X_FORWARDED_SCHEME" => "http").
        forwarded_scheme.must_equal "http"

      req("HTTP_FORWARDED"=>"proto=https",
        "HTTP_X_FORWARDED_PROTO" => "ws").
        forwarded_scheme.must_be_nil

      req("HTTP_FORWARDED"=>"proto=https").
        forwarded_scheme.must_be_nil

      Rack::Request.x_forwarded_proto_priority = [:proto]

      req("HTTP_FORWARDED"=>"proto=https",
        "HTTP_X_FORWARDED_PROTO" => "ws",
        "HTTP_X_FORWARDED_SCHEME" => "http").
        forwarded_scheme.must_equal "ws"

      req("HTTP_FORWARDED"=>"proto=https",
        "HTTP_X_FORWARDED_SCHEME" => "http").
        forwarded_scheme.must_be_nil

      req("HTTP_FORWARDED"=>"proto=https").
        forwarded_scheme.must_be_nil

      Rack::Request.x_forwarded_proto_priority = []

      req("HTTP_FORWARDED"=>"proto=https",
        "HTTP_X_FORWARDED_PROTO" => "ws",
        "HTTP_X_FORWARDED_SCHEME" => "http").
        forwarded_scheme.must_be_nil

      req("HTTP_FORWARDED"=>"proto=https",
        "HTTP_X_FORWARDED_SCHEME" => "http").
        forwarded_scheme.must_be_nil

      req("HTTP_FORWARDED"=>"proto=https").
        forwarded_scheme.must_be_nil

      Rack::Request.x_forwarded_proto_priority = default_proto_priority
      Rack::Request.forwarded_priority = [:forwarded]

      req("HTTP_FORWARDED"=>"proto=https",
        "HTTP_X_FORWARDED_PROTO" => "ws",
        "HTTP_X_FORWARDED_SCHEME" => "http").
        forwarded_scheme.must_equal 'https'

      req("HTTP_X_FORWARDED_PROTO" => "ws",
        "HTTP_X_FORWARDED_SCHEME" => "http").
        forwarded_scheme.must_be_nil

      req("HTTP_X_FORWARDED_PROTO" => "ws").
        forwarded_scheme.must_be_nil

      Rack::Request.forwarded_priority = []

      req("HTTP_FORWARDED"=>"for=1.2.3.4",
        "HTTP_X_FORWARDED_FOR" => "2.3.4.5").
        forwarded_for.must_be_nil

      req("HTTP_FORWARDED"=>"for=1.2.3.4",
        "HTTP_X_FORWARDED_PORT" => "2345").
        forwarded_port.must_be_nil

      req("HTTP_FORWARDED"=>"host=1.2.3.4, host=3.4.5.6",
        "HTTP_X_FORWARDED_HOST" => "2.3.4.5,4.5.6.7").
        forwarded_authority.must_be_nil

      req("HTTP_FORWARDED"=>"proto=https",
        "HTTP_X_FORWARDED_PROTO" => "ws",
        "HTTP_X_FORWARDED_SCHEME" => "http").
        forwarded_scheme.must_be_nil

      req("HTTP_FORWARDED"=>"proto=https",
        "HTTP_X_FORWARDED_SCHEME" => "http").
        forwarded_scheme.must_be_nil

      req("HTTP_FORWARDED"=>"proto=https").
        forwarded_scheme.must_be_nil

    ensure
      Rack::Request.forwarded_priority = default_priority
      Rack::Request.x_forwarded_proto_priority = default_proto_priority
    end
  end

  it "figure out the correct host with port" do
    req = make_request \
      Rack::MockRequest.env_for("/", "HTTP_HOST" => "www2.example.org")
    req.host_with_port.must_equal "www2.example.org"

    req = make_request \
      Rack::MockRequest.env_for("/", "HTTP_HOST" => "localhost:81")
    req.host_with_port.must_equal "localhost:81"

    req = make_request \
      Rack::MockRequest.env_for("/", "SERVER_NAME" => "example.org", "SERVER_PORT" => "9292")
    req.host_with_port.must_equal "example.org:9292"

    req = make_request \
      Rack::MockRequest.env_for("/", "SERVER_NAME" => "example.org")
    req.host_with_port.must_equal "example.org"

    req = make_request \
      Rack::MockRequest.env_for("/", "HTTP_HOST" => "localhost:81", "HTTP_X_FORWARDED_HOST" => "example.org:9292")
    req.host_with_port.must_equal "example.org:9292"

    req = make_request \
      Rack::MockRequest.env_for("/", "HTTP_HOST" => "localhost:81", "HTTP_X_FORWARDED_HOST" => "[2001:db8:cafe::17]:47011")
    req.host_with_port.must_equal "[2001:db8:cafe::17]:47011"

    req = make_request \
      Rack::MockRequest.env_for("/", "HTTP_HOST" => "localhost:81", "HTTP_X_FORWARDED_HOST" => "2001:db8:cafe::17")
    req.host_with_port.must_equal "[2001:db8:cafe::17]"

    req = make_request \
      Rack::MockRequest.env_for("/", "HTTP_HOST" => "localhost:81", "HTTP_X_FORWARDED_HOST" => "example.org", "SERVER_PORT" => "9393")
    req.host_with_port.must_equal "example.org"

    req = make_request \
      Rack::MockRequest.env_for("/", "HTTP_HOST" => "localhost:81", "HTTP_X_FORWARDED_HOST" => "example.org", "HTTP_FORWARDED" => "host=example.com:9292", "SERVER_PORT" => "9393")
    req.host_with_port.must_equal "example.com:9292"
  end

  it "parse the query string" do
    request = make_request(Rack::MockRequest.env_for("/?foo=bar&quux=bla&nothing&empty="))
    request.query_string.must_equal "foo=bar&quux=bla&nothing&empty="
    request.GET.must_equal "foo" => "bar", "quux" => "bla", "nothing" => nil, "empty" => ""
    request.POST.must_be :empty?
    request.params.must_equal "foo" => "bar", "quux" => "bla", "nothing" => nil, "empty" => ""
  end

  it "handles invalid unicode in query string value" do
    request = make_request(Rack::MockRequest.env_for(qs = "/?foo=%81E"))
    request.query_string.must_equal "foo=%81E"
    request.GET.must_equal "foo" => "\x81E"
    request.POST.must_be :empty?
    request.params.must_equal "foo" => "\x81E"
  end

  it "handles invalid unicode in query string key" do
    request = make_request(Rack::MockRequest.env_for("/?foo%81E=1"))
    request.query_string.must_equal "foo%81E=1"
    request.GET.must_equal "foo\x81E" => "1"
    request.POST.must_be :empty?
    request.params.must_equal "foo\x81E" => "1"
  end

  it "not truncate query strings containing semi-colons #543 only in POST" do
    mr = Rack::MockRequest.env_for("/",
      "REQUEST_METHOD" => 'POST',
      :input => "foo=bar&quux=b;la")
    req = make_request mr
    req.query_string.must_equal ""
    req.GET.must_be :empty?
    req.POST.must_equal "foo" => "bar", "quux" => "b;la"
    req.params.must_equal req.GET.merge(req.POST)
  end

  it "should use the query_parser for query parsing" do
    c = Class.new(Rack::QueryParser::Params) do
      def initialize(*)
        super(){|h, k| h[k.to_s] if k.is_a?(Symbol)}
      end
    end
    parser = Rack::QueryParser.new(c, 100)
    c = Class.new(Rack::Request) do
      define_method(:query_parser) do
        parser
      end
    end
    req = c.new(Rack::MockRequest.env_for("/?foo=bar&quux=bla"))
    req.GET[:foo].must_equal "bar"
    req.GET[:quux].must_equal "bla"
    req.params[:foo].must_equal "bar"
    req.params[:quux].must_equal "bla"
  end

  it "does not use semi-colons as separators for query strings in GET" do
    req = make_request(Rack::MockRequest.env_for("/?foo=bar&quux=b;la;wun=duh"))
    req.query_string.must_equal "foo=bar&quux=b;la;wun=duh"
    req.GET.must_equal "foo" => "bar", "quux" => "b;la;wun=duh"
    req.POST.must_be :empty?
    req.params.must_equal "foo" => "bar", "quux" => "b;la;wun=duh"
  end

  it "limit the allowed parameter depth when parsing parameters" do
    env = Rack::MockRequest.env_for("/?a#{'[a]' * 40}=b")
    req = make_request(env)
    lambda { req.GET }.must_raise Rack::QueryParser::ParamsTooDeepError

    env = Rack::MockRequest.env_for("/?a#{'[a]' * 30}=b")
    req = make_request(env)
    params = req.GET
    30.times { params = params['a'] }
    params['a'].must_equal 'b'

    old, Rack::Utils.param_depth_limit = Rack::Utils.param_depth_limit, 3
    begin
      env = Rack::MockRequest.env_for("/?a[a][a]=b")
      req = make_request(env)
      req.GET['a']['a']['a'].must_equal 'b'

      env = Rack::MockRequest.env_for("/?a[a][a][a]=b")
      req = make_request(env)
      lambda { make_request(env).GET  }.must_raise Rack::QueryParser::ParamsTooDeepError
    ensure
      Rack::Utils.param_depth_limit = old
    end
  end

  it "not unify GET and POST when calling params" do
    mr = Rack::MockRequest.env_for("/?foo=quux",
      "REQUEST_METHOD" => 'POST',
      :input => "foo=bar&quux=bla"
    )
    req = make_request mr

    req.params

    req.GET.must_equal "foo" => "quux"
    req.POST.must_equal "foo" => "bar", "quux" => "bla"
    req.params.must_equal req.GET.merge(req.POST)
  end

  it "use the query_parser's params_class for multipart params" do
    c = Class.new(Rack::QueryParser::Params) do
      def initialize(*)
        super(){|h, k| h[k.to_s] if k.is_a?(Symbol)}
      end
    end
    parser = Rack::QueryParser.new(c, 100)
    c = Class.new(Rack::Request) do
      define_method(:query_parser) do
        parser
      end
    end
    mr = Rack::MockRequest.env_for("/?foo=quux",
      "REQUEST_METHOD" => 'POST',
      :input => "foo=bar&quux=bla"
    )
    req = c.new mr

    req.params

    req.GET[:foo].must_equal "quux"
    req.POST[:foo].must_equal "bar"
    req.POST[:quux].must_equal "bla"
    req.params[:foo].must_equal "bar"
    req.params[:quux].must_equal "bla"
  end

  it "raise if input params has invalid %-encoding" do
    mr = Rack::MockRequest.env_for("/?foo=quux",
      "REQUEST_METHOD" => 'POST',
      :input => "a%=1"
    )
    req = make_request mr

    lambda { req.POST }.must_raise(Rack::Utils::InvalidParameterError).
      message.must_equal "invalid %-encoding (a%)"
  end

  it "return empty POST data if rack.input is missing" do
    req = make_request({})
    req.POST.must_be_empty
  end

  it "parse POST data when method is POST and no content-type given" do
    req = make_request \
      Rack::MockRequest.env_for("/?foo=quux",
        "REQUEST_METHOD" => 'POST',
        :input => "foo=bar&quux=bla")
    req.content_type.must_be_nil
    req.media_type.must_be_nil
    req.query_string.must_equal "foo=quux"
    req.GET.must_equal "foo" => "quux"
    req.POST.must_equal "foo" => "bar", "quux" => "bla"
    req.params.must_equal "foo" => "bar", "quux" => "bla"
  end

  it "parse POST data with explicit content type regardless of method" do
    req = make_request \
      Rack::MockRequest.env_for("/",
        "CONTENT_TYPE" => 'application/x-www-form-urlencoded;foo=bar',
        :input => "foo=bar&quux=bla")
    req.content_type.must_equal 'application/x-www-form-urlencoded;foo=bar'
    req.media_type.must_equal 'application/x-www-form-urlencoded'
    req.media_type_params['foo'].must_equal 'bar'
    req.POST.must_equal "foo" => "bar", "quux" => "bla"
    req.params.must_equal "foo" => "bar", "quux" => "bla"
  end

  it "not parse POST data when media type is not form-data" do
    req = make_request \
      Rack::MockRequest.env_for("/?foo=quux",
        "REQUEST_METHOD" => 'POST',
        "CONTENT_TYPE" => 'text/plain;charset=utf-8',
        :input => "foo=bar&quux=bla")
    req.content_type.must_equal 'text/plain;charset=utf-8'
    req.media_type.must_equal 'text/plain'
    req.media_type_params['charset'].must_equal 'utf-8'
    req.content_charset.must_equal 'utf-8'
    post = req.POST
    post.must_be_empty
    req.POST.must_be_same_as post
    req.params.must_equal "foo" => "quux"
    req.body.read.must_equal "foo=bar&quux=bla"
  end

  it "parse POST data on PUT when media type is form-data" do
    req = make_request \
      Rack::MockRequest.env_for("/?foo=quux",
        "REQUEST_METHOD" => 'PUT',
        "CONTENT_TYPE" => 'application/x-www-form-urlencoded',
        :input => "foo=bar&quux=bla")
    req.POST.must_equal "foo" => "bar", "quux" => "bla"
  end

  it "safely accepts POST requests with empty body" do
    mr = Rack::MockRequest.env_for("/",
      "REQUEST_METHOD" => "POST",
      "CONTENT_TYPE"   => "multipart/form-data; boundary=AaB03x",
      "CONTENT_LENGTH" => '0',
      :input => nil)

    req = make_request mr
    req.query_string.must_equal ""
    req.GET.must_be :empty?
    req.POST.must_be :empty?
    req.params.must_equal({})
  end

  it "clean up Safari's ajax POST body" do
    req = make_request \
      Rack::MockRequest.env_for("/",
        'REQUEST_METHOD' => 'POST', :input => "foo=bar&quux=bla\0")
    req.POST.must_equal "foo" => "bar", "quux" => "bla"
  end

  it "extract referrer correctly" do
    req = make_request \
      Rack::MockRequest.env_for("/", "HTTP_REFERER" => "/some/path")
    req.referer.must_equal "/some/path"

    req = make_request \
      Rack::MockRequest.env_for("/")
    req.referer.must_be_nil
  end

  it "extract user agent correctly" do
    req = make_request \
      Rack::MockRequest.env_for("/", "HTTP_USER_AGENT" => "Mozilla/4.0 (compatible)")
    req.user_agent.must_equal "Mozilla/4.0 (compatible)"

    req = make_request \
      Rack::MockRequest.env_for("/")
    req.user_agent.must_be_nil
  end

  it "treat missing content type as nil" do
    req = make_request \
      Rack::MockRequest.env_for("/")
    req.content_type.must_be_nil
  end

  it "treat empty content type as nil" do
    req = make_request \
      Rack::MockRequest.env_for("/", "CONTENT_TYPE" => "")
    req.content_type.must_be_nil
  end

  it "return nil media type for empty content type" do
    req = make_request \
      Rack::MockRequest.env_for("/", "CONTENT_TYPE" => "")
    req.media_type.must_be_nil
  end

  it "figure out if called via XHR" do
    req = make_request(Rack::MockRequest.env_for(""))
    req.wont_be :xhr?

    req = make_request \
      Rack::MockRequest.env_for("", "HTTP_X_REQUESTED_WITH" => "XMLHttpRequest")
    req.must_be :xhr?
  end

  it "ssl detection" do
    request = make_request(Rack::MockRequest.env_for("/"))
    request.scheme.must_equal "http"
    request.wont_be :ssl?

    request = make_request(Rack::MockRequest.env_for("/", 'HTTP_X_FORWARDED_SCHEME' => 'ws'))
    request.scheme.must_equal "ws"
    request.wont_be :ssl?

    request = make_request(Rack::MockRequest.env_for("/", 'HTTP_X_FORWARDED_PROTO' => 'ws'))
    request.scheme.must_equal "ws"

    request = make_request(Rack::MockRequest.env_for("/", 'HTTP_FORWARDED' => 'proto=https'))
    request.scheme.must_equal "https"
    request.must_be :ssl?

    request = make_request(Rack::MockRequest.env_for("/", 'HTTP_FORWARDED' => 'proto=https, proto=http'))
    request.scheme.must_equal "http"
    request.wont_be :ssl?

    request = make_request(Rack::MockRequest.env_for("/", 'HTTP_FORWARDED' => 'proto=http, proto=https'))
    request.scheme.must_equal "https"
    request.must_be :ssl?

    request = make_request(Rack::MockRequest.env_for("/", 'HTTPS' => 'on'))
    request.scheme.must_equal "https"
    request.must_be :ssl?

    request = make_request(Rack::MockRequest.env_for("/", 'rack.url_scheme' => 'https'))
    request.scheme.must_equal "https"
    request.must_be :ssl?

    request = make_request(Rack::MockRequest.env_for("/", 'rack.url_scheme' => 'wss'))
    request.scheme.must_equal "wss"
    request.must_be :ssl?

    request = make_request(Rack::MockRequest.env_for("/", 'HTTP_HOST' => 'www.example.org:8080'))
    request.scheme.must_equal "http"
    request.wont_be :ssl?

    request = make_request(Rack::MockRequest.env_for("/", 'HTTP_HOST' => 'www.example.org:8443', 'HTTPS' => 'on'))
    request.scheme.must_equal "https"
    request.must_be :ssl?

    request = make_request(Rack::MockRequest.env_for("/", 'HTTP_HOST' => 'www.example.org:8443', 'HTTP_X_FORWARDED_SSL' => 'on'))
    request.scheme.must_equal "https"
    request.must_be :ssl?

    request = make_request(Rack::MockRequest.env_for("/", 'HTTP_X_FORWARDED_SCHEME' => 'https'))
    request.scheme.must_equal "https"
    request.must_be :ssl?

    request = make_request(Rack::MockRequest.env_for("/", 'HTTP_X_FORWARDED_SCHEME' => 'wss'))
    request.scheme.must_equal "wss"
    request.must_be :ssl?

    request = make_request(Rack::MockRequest.env_for("/", 'HTTP_X_FORWARDED_PROTO' => 'https'))
    request.scheme.must_equal "https"
    request.must_be :ssl?

    request = make_request(Rack::MockRequest.env_for("/", 'HTTP_X_FORWARDED_PROTO' => 'https, http, http'))
    request.scheme.must_equal "http"
    request.wont_be :ssl?

    request = make_request(Rack::MockRequest.env_for("/", 'HTTP_X_FORWARDED_PROTO' => 'wss'))
    request.scheme.must_equal "wss"
    request.must_be :ssl?
  end

  it "prevents scheme abuse" do
    request = make_request(Rack::MockRequest.env_for("/", 'HTTP_X_FORWARDED_SCHEME' => 'a."><script>alert(1)</script>'))
    request.scheme.must_equal 'http'
  end

  it "parse cookies" do
    req = make_request \
      Rack::MockRequest.env_for("", "HTTP_COOKIE" => "foo=bar;quux=h&m")
    req.cookies.must_equal "foo" => "bar", "quux" => "h&m"
    req.delete_header("HTTP_COOKIE")
    req.cookies.must_equal({})
  end

  it "always return the same hash object" do
    req = make_request \
      Rack::MockRequest.env_for("", "HTTP_COOKIE" => "foo=bar;quux=h&m")
    hash = req.cookies
    req.env.delete("HTTP_COOKIE")
    req.cookies.must_equal hash
    req.env["HTTP_COOKIE"] = "zoo=m"
    req.cookies.must_equal hash
  end

  it "modify the cookies hash in place" do
    req = make_request(Rack::MockRequest.env_for(""))
    req.cookies.must_equal({})
    req.cookies['foo'] = 'bar'
    req.cookies.must_equal 'foo' => 'bar'
  end

  it "not modify the params hash in place" do
    e = Rack::MockRequest.env_for("")
    req1 = make_request(e)
    if req1.delegate?
      skip "delegate requests don't cache params, so mutations have no impact"
    end
    req1.params.must_equal({})
    req1.params['foo'] = 'bar'
    req1.params.must_equal 'foo' => 'bar'
    req2 = make_request(e)
    req2.params.must_equal({})
  end

  it "modify params hash if param is in GET" do
    e = Rack::MockRequest.env_for("?foo=duh")
    req1 = make_request(e)
    req1.params.must_equal 'foo' => 'duh'
    req1.update_param 'foo', 'bar'
    req1.params.must_equal 'foo' => 'bar'
    req2 = make_request(e)
    req2.params.must_equal 'foo' => 'bar'
  end

  it "modify params hash if param is in POST" do
    e = Rack::MockRequest.env_for("", "REQUEST_METHOD" => 'POST', :input => 'foo=duh')
    req1 = make_request(e)
    req1.params.must_equal 'foo' => 'duh'
    req1.update_param 'foo', 'bar'
    req1.params.must_equal 'foo' => 'bar'
    req2 = make_request(e)
    req2.params.must_equal 'foo' => 'bar'
  end

  it "modify params hash, even if param didn't exist before" do
    e = Rack::MockRequest.env_for("")
    req1 = make_request(e)
    req1.params.must_equal({})
    req1.update_param 'foo', 'bar'
    req1.params.must_equal 'foo' => 'bar'
    req2 = make_request(e)
    req2.params.must_equal 'foo' => 'bar'
  end

  it "modify params hash by changing only GET" do
    e = Rack::MockRequest.env_for("?foo=duhget")
    req = make_request(e)
    req.GET.must_equal 'foo' => 'duhget'
    req.POST.must_equal({})
    req.update_param 'foo', 'bar'
    req.GET.must_equal 'foo' => 'bar'
    req.POST.must_equal({})
  end

  it "modify params hash by changing only POST" do
    e = Rack::MockRequest.env_for("", "REQUEST_METHOD" => 'POST', :input => "foo=duhpost")
    req = make_request(e)
    req.GET.must_equal({})
    req.POST.must_equal 'foo' => 'duhpost'
    req.update_param 'foo', 'bar'
    req.GET.must_equal({})
    req.POST.must_equal 'foo' => 'bar'
  end

  it "modify params hash, even if param is defined in both POST and GET" do
    e = Rack::MockRequest.env_for("?foo=duhget", "REQUEST_METHOD" => 'POST', :input => "foo=duhpost")
    req1 = make_request(e)
    req1.GET.must_equal 'foo' => 'duhget'
    req1.POST.must_equal 'foo' => 'duhpost'
    req1.params.must_equal 'foo' => 'duhpost'
    req1.update_param 'foo', 'bar'
    req1.GET.must_equal 'foo' => 'bar'
    req1.POST.must_equal 'foo' => 'bar'
    req1.params.must_equal 'foo' => 'bar'
    req2 = make_request(e)
    req2.GET.must_equal 'foo' => 'bar'
    req2.POST.must_equal 'foo' => 'bar'
    req2.params.must_equal 'foo' => 'bar'
    req2.params.must_equal 'foo' => 'bar'
  end

  it "allow deleting from params hash if param is in GET" do
    e = Rack::MockRequest.env_for("?foo=bar")
    req1 = make_request(e)
    req1.params.must_equal 'foo' => 'bar'
    req1.delete_param('foo').must_equal 'bar'
    req1.params.must_equal({})
    req2 = make_request(e)
    req2.params.must_equal({})
  end

  it "allow deleting from params hash if param is in POST" do
    e = Rack::MockRequest.env_for("", "REQUEST_METHOD" => 'POST', :input => 'foo=bar')
    req1 = make_request(e)
    req1.params.must_equal 'foo' => 'bar'
    req1.delete_param('foo').must_equal 'bar'
    req1.params.must_equal({})
    req2 = make_request(e)
    req2.params.must_equal({})
  end

  it "pass through non-uri escaped cookies as-is" do
    req = make_request Rack::MockRequest.env_for("", "HTTP_COOKIE" => "foo=%")
    req.cookies["foo"].must_equal "%"
  end

  it "parse cookies according to RFC 2109" do
    req = make_request \
      Rack::MockRequest.env_for('', 'HTTP_COOKIE' => 'foo=bar;foo=car')
    req.cookies.must_equal 'foo' => 'bar'
  end

  it 'parse cookies with quotes' do
    req = make_request Rack::MockRequest.env_for('', {
      'HTTP_COOKIE' => '$Version="1"; Customer="WILE_E_COYOTE"; $Path="/acme"; Part_Number="Rocket_Launcher_0001"; $Path="/acme"'
    })
    req.cookies.must_equal({
      '$Version'    => '"1"',
      'Customer'    => '"WILE_E_COYOTE"',
      '$Path'       => '"/acme"',
      'Part_Number' => '"Rocket_Launcher_0001"',
    })
  end

  it "provide setters" do
    req = make_request(e = Rack::MockRequest.env_for(""))
    req.script_name.must_equal ""
    req.script_name = "/foo"
    req.script_name.must_equal "/foo"
    e["SCRIPT_NAME"].must_equal "/foo"

    req.path_info.must_equal "/"
    req.path_info = "/foo"
    req.path_info.must_equal "/foo"
    e["PATH_INFO"].must_equal "/foo"
  end

  it "provide the original env" do
    req = make_request(e = Rack::MockRequest.env_for(""))
    req.env.must_equal e
  end

  it "restore the base URL" do
    make_request(Rack::MockRequest.env_for("")).base_url.
      must_equal "http://example.org"
    make_request(Rack::MockRequest.env_for("", "SCRIPT_NAME" => "/foo")).base_url.
      must_equal "http://example.org"
  end

  it "restore the URL" do
    make_request(Rack::MockRequest.env_for("")).url.
      must_equal "http://example.org/"
    make_request(Rack::MockRequest.env_for("", "SCRIPT_NAME" => "/foo")).url.
      must_equal "http://example.org/foo/"
    make_request(Rack::MockRequest.env_for("/foo")).url.
      must_equal "http://example.org/foo"
    make_request(Rack::MockRequest.env_for("?foo")).url.
      must_equal "http://example.org/?foo"
    make_request(Rack::MockRequest.env_for("http://example.org:8080/")).url.
      must_equal "http://example.org:8080/"
    make_request(Rack::MockRequest.env_for("https://example.org/")).url.
      must_equal "https://example.org/"
    make_request(Rack::MockRequest.env_for("coffee://example.org/")).url.
      must_equal "coffee://example.org/"
    make_request(Rack::MockRequest.env_for("coffee://example.org:443/")).url.
      must_equal "coffee://example.org:443/"
    make_request(Rack::MockRequest.env_for("https://example.com:8080/foo?foo")).url.
      must_equal "https://example.com:8080/foo?foo"
  end

  it "restore the full path" do
    make_request(Rack::MockRequest.env_for("")).fullpath.
      must_equal "/"
    make_request(Rack::MockRequest.env_for("", "SCRIPT_NAME" => "/foo")).fullpath.
      must_equal "/foo/"
    make_request(Rack::MockRequest.env_for("/foo")).fullpath.
      must_equal "/foo"
    make_request(Rack::MockRequest.env_for("?foo")).fullpath.
      must_equal "/?foo"
    make_request(Rack::MockRequest.env_for("http://example.org:8080/")).fullpath.
      must_equal "/"
    make_request(Rack::MockRequest.env_for("https://example.org/")).fullpath.
      must_equal "/"

    make_request(Rack::MockRequest.env_for("https://example.com:8080/foo?foo")).fullpath.
     must_equal "/foo?foo"
  end

  it "handle multiple media type parameters" do
    req = make_request \
      Rack::MockRequest.env_for("/",
        "CONTENT_TYPE" => 'text/plain; foo=BAR,baz=bizzle dizzle;BLING=bam;blong="boo";zump="zoo\"o";weird=lol"')
      req.wont_be :form_data?
      req.media_type_params.must_include 'foo'
      req.media_type_params['foo'].must_equal 'BAR'
      req.media_type_params.must_include 'baz'
      req.media_type_params['baz'].must_equal 'bizzle dizzle'
      req.media_type_params.wont_include 'BLING'
      req.media_type_params.must_include 'bling'
      req.media_type_params['bling'].must_equal 'bam'
      req.media_type_params['blong'].must_equal 'boo'
      req.media_type_params['zump'].must_equal 'zoo\"o'
      req.media_type_params['weird'].must_equal 'lol"'
  end

  it "returns the same error for invalid post inputs" do
    env = {
      'REQUEST_METHOD' => 'POST',
      'PATH_INFO' => '/foo',
      'rack.input' => StringIO.new('invalid=bar&invalid[foo]=bar'),
      'HTTP_CONTENT_TYPE' => "application/x-www-form-urlencoded",
    }
    
    2.times do
      # The actual exception type here is unimportant - just that it fails.
      assert_raises(Rack::Utils::ParameterTypeError) do
        Rack::Request.new(env).POST
      end
    end
  end

  it "parse with junk before boundary" do
    # Adapted from RFC 1867.
    input = <<EOF
blah blah\r
\r
--AaB03x\r
content-disposition: form-data; name="reply"\r
\r
yes\r
--AaB03x\r
content-disposition: form-data; name="fileupload"; filename="dj.jpg"\r
content-type: image/jpeg\r
content-transfer-encoding: base64\r
\r
/9j/4AAQSkZJRgABAQAAAQABAAD//gA+Q1JFQVRPUjogZ2QtanBlZyB2MS4wICh1c2luZyBJSkcg\r
--AaB03x--\r
EOF
    req = make_request Rack::MockRequest.env_for("/",
                      "CONTENT_TYPE" => "multipart/form-data; boundary=AaB03x",
                      "CONTENT_LENGTH" => input.size,
                      :input => input)

    req.POST.must_include "fileupload"
    req.POST.must_include "reply"

    req.must_be :form_data?
    req.content_length.must_equal input.size
    req.media_type.must_equal 'multipart/form-data'
    req.media_type_params.must_include 'boundary'
    req.media_type_params['boundary'].must_equal 'AaB03x'

    req.POST["reply"].must_equal "yes"

    f = req.POST["fileupload"]
    f.must_be_kind_of Hash
    f[:type].must_equal "image/jpeg"
    f[:filename].must_equal "dj.jpg"
    f.must_include :tempfile
    f[:tempfile].size.must_equal 76
  end

  it "not infinite loop with a malformed HTTP request" do
    # Adapted from RFC 1867.
    input = <<EOF
--AaB03x
content-disposition: form-data; name="reply"

yes
--AaB03x
content-disposition: form-data; name="fileupload"; filename="dj.jpg"
content-type: image/jpeg
content-transfer-encoding: base64

/9j/4AAQSkZJRgABAQAAAQABAAD//gA+Q1JFQVRPUjogZ2QtanBlZyB2MS4wICh1c2luZyBJSkcg
--AaB03x--
EOF
    req = make_request Rack::MockRequest.env_for("/",
                      "CONTENT_TYPE" => "multipart/form-data; boundary=AaB03x",
                      "CONTENT_LENGTH" => input.size,
                      :input => input)

    lambda{req.POST}.must_raise EOFError
  end


  it "parse multipart form data" do
    # Adapted from RFC 1867.
    input = <<EOF
--AaB03x\r
content-disposition: form-data; name="reply"\r
\r
yes\r
--AaB03x\r
content-disposition: form-data; name="fileupload"; filename="dj.jpg"\r
content-type: image/jpeg\r
content-transfer-encoding: base64\r
\r
/9j/4AAQSkZJRgABAQAAAQABAAD//gA+Q1JFQVRPUjogZ2QtanBlZyB2MS4wICh1c2luZyBJSkcg\r
--AaB03x--\r
EOF
    req = make_request Rack::MockRequest.env_for("/",
                      "CONTENT_TYPE" => "multipart/form-data; boundary=AaB03x",
                      "CONTENT_LENGTH" => input.size,
                      :input => input)

    req.POST.must_include "fileupload"
    req.POST.must_include "reply"

    req.must_be :form_data?
    req.content_length.must_equal input.size
    req.media_type.must_equal 'multipart/form-data'
    req.media_type_params.must_include 'boundary'
    req.media_type_params['boundary'].must_equal 'AaB03x'

    req.POST["reply"].must_equal "yes"

    f = req.POST["fileupload"]
    f.must_be_kind_of Hash
    f[:type].must_equal "image/jpeg"
    f[:filename].must_equal "dj.jpg"
    f.must_include :tempfile
    f[:tempfile].size.must_equal 76

    req.env['rack.request.form_pairs'].must_equal [["reply", "yes"], ["fileupload", f]]
  end

  it "parse multipart delimiter-only boundary" do
    input = <<EOF
--AaB03x--\r
EOF
    mr = Rack::MockRequest.env_for(
      "/",
      "CONTENT_TYPE" => "multipart/form-data; boundary=AaB03x",
      "CONTENT_LENGTH" => input.size,
      :input => input
    )

    req = make_request mr
    req.query_string.must_equal ""
    req.GET.must_be :empty?
    req.POST.must_be :empty?
    req.params.must_equal({})
  end

  it "MultipartPartLimitError when request has too many multipart file parts if limit set" do
    begin
      data = 10000.times.map { "--AaB03x\r\ncontent-type: text/plain\r\ncontent-disposition: attachment; name=#{SecureRandom.hex(10)}; filename=#{SecureRandom.hex(10)}\r\n\r\ncontents\r\n" }.join("\r\n")
      data += "--AaB03x--\r"

      options = {
        "CONTENT_TYPE" => "multipart/form-data; boundary=AaB03x",
        "CONTENT_LENGTH" => data.length.to_s,
        :input => StringIO.new(data)
      }

      request = make_request Rack::MockRequest.env_for("/", options)
      lambda { request.POST }.must_raise Rack::Multipart::MultipartPartLimitError
    end
  end

  it "MultipartPartLimitError when request has too many multipart total parts if limit set" do
    begin
      data = 10000.times.map { "--AaB03x\r\ncontent-type: text/plain\r\ncontent-disposition: attachment; name=#{SecureRandom.hex(10)}\r\n\r\ncontents\r\n" }.join("\r\n")
      data += "--AaB03x--\r"

      options = {
        "CONTENT_TYPE" => "multipart/form-data; boundary=AaB03x",
        "CONTENT_LENGTH" => data.length.to_s,
        :input => StringIO.new(data)
      }

      request = make_request Rack::MockRequest.env_for("/", options)
      lambda { request.POST }.must_raise Rack::Multipart::MultipartTotalPartLimitError
    end
  end

  it 'closes tempfiles it created in the case of too many created' do
    begin
      data = 10000.times.map { "--AaB03x\r\ncontent-type: text/plain\r\ncontent-disposition: attachment; name=#{SecureRandom.hex(10)}; filename=#{SecureRandom.hex(10)}\r\n\r\ncontents\r\n" }.join("\r\n")
      data += "--AaB03x--\r"

      files = []
      options = {
        "CONTENT_TYPE" => "multipart/form-data; boundary=AaB03x",
        "CONTENT_LENGTH" => data.length.to_s,
        Rack::RACK_MULTIPART_TEMPFILE_FACTORY => lambda { |filename, content_type|
          file = Tempfile.new(["RackMultipart", ::File.extname(filename)])
          files << file
          file
        },
        :input => StringIO.new(data)
      }

      request = make_request Rack::MockRequest.env_for("/", options)
      assert_raises(Rack::Multipart::MultipartPartLimitError) do
        request.POST
      end
      refute_predicate files, :empty?
      files.each { |f| assert_predicate f, :closed? }
    end
  end

  it "parse big multipart form data" do
    input = <<EOF
--AaB03x\r
content-disposition: form-data; name="huge"; filename="huge"\r
\r
#{"x" * 32768}\r
--AaB03x\r
content-disposition: form-data; name="mean"; filename="mean"\r
\r
--AaB03xha\r
--AaB03x--\r
EOF
    req = make_request Rack::MockRequest.env_for("/",
                      "CONTENT_TYPE" => "multipart/form-data; boundary=AaB03x",
                      "CONTENT_LENGTH" => input.size,
                      :input => input)

    req.POST["huge"][:tempfile].size.must_equal 32768
    req.POST["mean"][:tempfile].size.must_equal 10
    req.POST["mean"][:tempfile].read.must_equal "--AaB03xha"
  end

  it "record tempfiles from multipart form data in env[rack.tempfiles]" do
    input = <<EOF
--AaB03x\r
content-disposition: form-data; name="fileupload"; filename="foo.jpg"\r
content-type: image/jpeg\r
content-transfer-encoding: base64\r
\r
/9j/4AAQSkZJRgABAQAAAQABAAD//gA+Q1JFQVRPUjogZ2QtanBlZyB2MS4wICh1c2luZyBJSkcg\r
--AaB03x\r
content-disposition: form-data; name="fileupload"; filename="bar.jpg"\r
content-type: image/jpeg\r
content-transfer-encoding: base64\r
\r
/9j/4AAQSkZJRgABAQAAAQABAAD//gA+Q1JFQVRPUjogZ2QtanBlZyB2MS4wICh1c2luZyBJSkcg\r
--AaB03x--\r
EOF
    env = Rack::MockRequest.env_for("/",
                          "CONTENT_TYPE" => "multipart/form-data; boundary=AaB03x",
                          "CONTENT_LENGTH" => input.size,
                          :input => input)
    req = make_request(env)
    req.params
    env['rack.tempfiles'].size.must_equal 2
  end

  it "detect invalid multipart form data" do
    input = <<EOF
--AaB03x\r
content-disposition: form-data; name="huge"; filename="huge"\r
EOF
    req = make_request Rack::MockRequest.env_for("/",
                      "CONTENT_TYPE" => "multipart/form-data; boundary=AaB03x",
                      "CONTENT_LENGTH" => input.size,
                      :input => input)

    lambda { req.POST }.must_raise EOFError

    input = <<EOF
--AaB03x\r
content-disposition: form-data; name="huge"; filename="huge"\r
\r
foo\r
EOF
    req = make_request Rack::MockRequest.env_for("/",
                      "CONTENT_TYPE" => "multipart/form-data; boundary=AaB03x",
                      "CONTENT_LENGTH" => input.size,
                      :input => input)

    lambda { req.POST }.must_raise EOFError

    input = <<EOF
--AaB03x\r
content-disposition: form-data; name="huge"; filename="huge"\r
\r
foo\r
EOF
    req = make_request Rack::MockRequest.env_for("/",
                      "CONTENT_TYPE" => "multipart/form-data; boundary=AaB03x",
                      "CONTENT_LENGTH" => input.size,
                      :input => input)

    lambda { req.POST }.must_raise EOFError
  end

  it "consistently raise EOFError on bad multipart form data" do
    input = <<EOF
--AaB03x\r
content-disposition: form-data; name="huge"; filename="huge"\r
EOF
    req = make_request Rack::MockRequest.env_for("/",
                      "CONTENT_TYPE" => "multipart/form-data; boundary=AaB03x",
                      "CONTENT_LENGTH" => input.size,
                      :input => input)

    lambda { req.POST }.must_raise EOFError
    lambda { req.POST }.must_raise EOFError
  end

  it "correctly parse the part name from Content-Id header" do
    input = <<EOF
--AaB03x\r
content-type: text/xml; charset=utf-8\r
Content-Id: <soap-start>\r
content-transfer-encoding: 7bit\r
\r
foo\r
--AaB03x--\r
EOF
    req = make_request Rack::MockRequest.env_for("/",
                      "CONTENT_TYPE" => "multipart/related; boundary=AaB03x",
                      "CONTENT_LENGTH" => input.size,
                      :input => input)

    req.params.keys.must_equal ["<soap-start>"]
  end

  it "not try to interpret binary as utf8" do
        input = <<EOF
--AaB03x\r
content-disposition: form-data; name="fileupload"; filename="junk.a"\r
content-type: application/octet-stream\r
\r
#{[0x36, 0xCF, 0x0A, 0xF8].pack('c*')}\r
--AaB03x--\r
EOF

        req = make_request Rack::MockRequest.env_for("/",
                          "CONTENT_TYPE" => "multipart/form-data; boundary=AaB03x",
                          "CONTENT_LENGTH" => input.size,
                          :input => input)

    req.POST["fileupload"][:tempfile].size.must_equal 4
  end

  it "use form_hash when form_input is a Tempfile" do
    input = "{foo: 'bar'}"

    rack_input = Tempfile.new("rackspec")
    rack_input.write(input)
    rack_input.rewind

    form_hash = {}

    req = make_request Rack::MockRequest.env_for(
      "/",
      "rack.request.form_hash" => form_hash,
      "rack.request.form_input" => rack_input,
      :input => rack_input
    )

    req.POST.must_be_same_as form_hash
  end

  it "conform to the Rack spec" do
    app = lambda { |env|
      content = make_request(env).POST["file"].inspect
      size = content.bytesize
      [200, { "content-type" => "text/html", "content-length" => size.to_s }, [content]]
    }

    input = <<EOF.dup
--AaB03x\r
content-disposition: form-data; name="reply"\r
\r
yes\r
--AaB03x\r
content-disposition: form-data; name="fileupload"; filename="dj.jpg"\r
content-type: image/jpeg\r
content-transfer-encoding: base64\r
\r
/9j/4AAQSkZJRgABAQAAAQABAAD//gA+Q1JFQVRPUjogZ2QtanBlZyB2MS4wICh1c2luZyBJSkcg\r
--AaB03x--\r
EOF
    input.force_encoding(Encoding::ASCII_8BIT)
    res = Rack::MockRequest.new(Rack::Lint.new(app)).get "/",
      "CONTENT_TYPE" => "multipart/form-data; boundary=AaB03x",
      "CONTENT_LENGTH" => input.size.to_s, "rack.input" => StringIO.new(input)

    res.must_be :ok?
  end

  it "parse Accept-Encoding correctly" do
    parser = lambda do |x|
      make_request(Rack::MockRequest.env_for("", "HTTP_ACCEPT_ENCODING" => x)).accept_encoding
    end

    parser.call(nil).must_equal []

    parser.call("compress, gzip").must_equal [["compress", 1.0], ["gzip", 1.0]]
    parser.call("").must_equal []
    parser.call("*").must_equal [["*", 1.0]]
    parser.call("compress;q=0.5, gzip;q=1.0").must_equal [["compress", 0.5], ["gzip", 1.0]]
    parser.call("gzip;q=1.0, identity; q=0.5, *;q=0").must_equal [["gzip", 1.0], ["identity", 0.5], ["*", 0] ]

    parser.call("gzip ; q=0.9").must_equal [["gzip", 0.9]]
    parser.call("gzip ; deflate").must_equal [["gzip", 1.0]]

    parser.call(", ").must_equal []
    parser.call(", gzip").must_equal [["gzip", 1.0]]
    parser.call("gzip, ").must_equal [["gzip", 1.0]]
  end

  it "parse Accept-Language correctly" do
    parser = lambda do |x|
      make_request(Rack::MockRequest.env_for("", "HTTP_ACCEPT_LANGUAGE" => x)).accept_language
    end

    parser.call(nil).must_equal []

    parser.call("fr, en").must_equal [["fr", 1.0], ["en", 1.0]]
    parser.call("").must_equal []
    parser.call("*").must_equal [["*", 1.0]]
    parser.call("fr;q=0.5, en;q=1.0").must_equal [["fr", 0.5], ["en", 1.0]]
    parser.call("fr;q=1.0, en; q=0.5, *;q=0").must_equal [["fr", 1.0], ["en", 0.5], ["*", 0] ]

    parser.call("fr ; q=0.9").must_equal [["fr", 0.9]]
    parser.call("fr").must_equal [["fr", 1.0]]

    parser.call(", ").must_equal []
    parser.call(", en").must_equal [["en", 1.0]]
    parser.call("en, ").must_equal [["en", 1.0]]
  end

  def ip_app
    lambda { |env|
      request = make_request(env)
      response = Rack::Response.new
      response.write request.ip
      response.finish
    }
  end

  it 'provide ip information' do
    mock = Rack::MockRequest.new(Rack::Lint.new(ip_app))

    res = mock.get '/', 'REMOTE_ADDR' => '1.2.3.4'
    res.body.must_equal '1.2.3.4'

    res = mock.get '/', 'REMOTE_ADDR' => 'fe80::202:b3ff:fe1e:8329'
    res.body.must_equal 'fe80::202:b3ff:fe1e:8329'

    res = mock.get '/', 'REMOTE_ADDR' => '1.2.3.4,3.4.5.6'
    res.body.must_equal '3.4.5.6'

    res = mock.get '/', 'REMOTE_ADDR' => '127.0.0.1'
    res.body.must_equal '127.0.0.1'

    res = mock.get '/', 'REMOTE_ADDR' => '127.0.0.1,127.0.0.1'
    res.body.must_equal '127.0.0.1'
  end

  it 'deals with proxies' do
    mock = Rack::MockRequest.new(Rack::Lint.new(ip_app))

    res = mock.get '/',
      'REMOTE_ADDR' => '1.2.3.4',
      'HTTP_FORWARDED' => 'for=3.4.5.6'
    res.body.must_equal '1.2.3.4'

    res = mock.get '/',
      'HTTP_X_FORWARDED_FOR' => '3.4.5.6',
      'HTTP_FORWARDED' => 'for=5.6.7.8'
    res.body.must_equal '5.6.7.8'

    res = mock.get '/',
      'HTTP_X_FORWARDED_FOR' => '3.4.5.6',
      'HTTP_FORWARDED' => 'for=5.6.7.8, for=7.8.9.0'
    res.body.must_equal '7.8.9.0'

    res = mock.get '/',
      'REMOTE_ADDR' => '1.2.3.4',
      'HTTP_X_FORWARDED_FOR' => '3.4.5.6'
    res.body.must_equal '1.2.3.4'

    res = mock.get '/',
      'REMOTE_ADDR' => '1.2.3.4',
      'HTTP_X_FORWARDED_FOR' => 'unknown'
    res.body.must_equal '1.2.3.4'

    res = mock.get '/',
      'REMOTE_ADDR' => '127.0.0.1',
      'HTTP_X_FORWARDED_FOR' => '3.4.5.6'
    res.body.must_equal '3.4.5.6'

    res = mock.get '/', 'HTTP_X_FORWARDED_FOR' => 'unknown,3.4.5.6'
    res.body.must_equal '3.4.5.6'

    res = mock.get '/', 'HTTP_X_FORWARDED_FOR' => '192.168.0.1,3.4.5.6'
    res.body.must_equal '3.4.5.6'

    res = mock.get '/', 'HTTP_X_FORWARDED_FOR' => '10.0.0.1,3.4.5.6'
    res.body.must_equal '3.4.5.6'

    res = mock.get '/', 'HTTP_X_FORWARDED_FOR' => '10.0.0.1, 10.0.0.1, 3.4.5.6'
    res.body.must_equal '3.4.5.6'

    res = mock.get '/', 'HTTP_X_FORWARDED_FOR' => '127.0.0.1, 3.4.5.6'
    res.body.must_equal '3.4.5.6'

    # IPv6 format with optional port: "[2001:db8:cafe::17]:47011"
    res = mock.get '/', 'HTTP_X_FORWARDED_FOR' => '[2001:db8:cafe::17]:47011'
    res.body.must_equal '2001:db8:cafe::17'

    res = mock.get '/', 'HTTP_FORWARDED' => 'for="[2001:db8:cafe::17]:47011"'
    res.body.must_equal '2001:db8:cafe::17'

    res = mock.get '/', 'HTTP_X_FORWARDED_FOR' => '1.2.3.4, [2001:db8:cafe::17]:47011'
    res.body.must_equal '2001:db8:cafe::17'

    # IPv4 format with optional port: "192.0.2.43:47011"
    res = mock.get '/', 'HTTP_X_FORWARDED_FOR' => '192.0.2.43:47011'
    res.body.must_equal '192.0.2.43'

    res = mock.get '/', 'HTTP_X_FORWARDED_FOR' => '1.2.3.4, 192.0.2.43:47011'
    res.body.must_equal '192.0.2.43'

    res = mock.get '/', 'HTTP_X_FORWARDED_FOR' => 'unknown,192.168.0.1'
    res.body.must_equal 'unknown'

    res = mock.get '/', 'HTTP_X_FORWARDED_FOR' => 'other,unknown,192.168.0.1'
    res.body.must_equal 'unknown'

    res = mock.get '/', 'HTTP_X_FORWARDED_FOR' => 'unknown,localhost,192.168.0.1'
    res.body.must_equal 'unknown'

    res = mock.get '/', 'HTTP_X_FORWARDED_FOR' => '9.9.9.9, 3.4.5.6, 10.0.0.1, 172.31.4.4'
    res.body.must_equal '3.4.5.6'

    res = mock.get '/', 'HTTP_X_FORWARDED_FOR' => '::1,2620:0:1c00:0:812c:9583:754b:ca11'
    res.body.must_equal '2620:0:1c00:0:812c:9583:754b:ca11'

    res = mock.get '/', 'HTTP_X_FORWARDED_FOR' => '2620:0:1c00:0:812c:9583:754b:ca11,::1'
    res.body.must_equal '2620:0:1c00:0:812c:9583:754b:ca11'

    res = mock.get '/', 'HTTP_X_FORWARDED_FOR' => 'fd5b:982e:9130:247f:0000:0000:0000:0000,2620:0:1c00:0:812c:9583:754b:ca11'
    res.body.must_equal '2620:0:1c00:0:812c:9583:754b:ca11'

    res = mock.get '/', 'HTTP_X_FORWARDED_FOR' => '2620:0:1c00:0:812c:9583:754b:ca11,fd5b:982e:9130:247f:0000:0000:0000:0000'
    res.body.must_equal '2620:0:1c00:0:812c:9583:754b:ca11'

    res = mock.get '/',
      'HTTP_X_FORWARDED_FOR' => '1.1.1.1, 127.0.0.1',
      'HTTP_CLIENT_IP' => '1.1.1.1'
    res.body.must_equal '1.1.1.1'

    res = mock.get '/', 'HTTP_X_FORWARDED_FOR' => '8.8.8.8, 9.9.9.9'
    res.body.must_equal '9.9.9.9'

    res = mock.get '/', 'HTTP_X_FORWARDED_FOR' => '8.8.8.8, fe80::202:b3ff:fe1e:8329'
    res.body.must_equal 'fe80::202:b3ff:fe1e:8329'

    # Unix Sockets
    res = mock.get '/',
      'REMOTE_ADDR' => 'unix',
      'HTTP_X_FORWARDED_FOR' => '3.4.5.6'
    res.body.must_equal '3.4.5.6'

    res = mock.get '/',
      'REMOTE_ADDR' => 'unix:/tmp/foo',
      'HTTP_X_FORWARDED_FOR' => '3.4.5.6'
    res.body.must_equal '3.4.5.6'
  end

  it "not allow IP spoofing via Client-IP and X-Forwarded-For headers" do
    mock = Rack::MockRequest.new(Rack::Lint.new(ip_app))

    # IP Spoofing attempt:
    # Client sends          X-Forwarded-For: 6.6.6.6
    #                       Client-IP: 6.6.6.6
    # Load balancer adds    X-Forwarded-For: 2.2.2.3, 192.168.0.7
    # App receives:         X-Forwarded-For: 6.6.6.6
    #                       X-Forwarded-For: 2.2.2.3, 192.168.0.7
    #                       Client-IP: 6.6.6.6
    # Rack env:             HTTP_X_FORWARDED_FOR: '6.6.6.6, 2.2.2.3, 192.168.0.7'
    #                       HTTP_CLIENT_IP: '6.6.6.6'
    res = mock.get '/',
      'HTTP_X_FORWARDED_FOR' => '6.6.6.6, 2.2.2.3, 192.168.0.7',
      'HTTP_CLIENT_IP' => '6.6.6.6'
    res.body.must_equal '2.2.2.3'
  end

  it "preserves ip for trusted proxy chain" do
    mock = Rack::MockRequest.new(Rack::Lint.new(ip_app))
    res = mock.get '/',
      'HTTP_X_FORWARDED_FOR' => '192.168.0.11, 192.168.0.7',
      'HTTP_CLIENT_IP' => '127.0.0.1'
    res.body.must_equal '192.168.0.11'

  end

  it "uses a custom trusted proxy filter" do
    old_ip = Rack::Request.ip_filter
    Rack::Request.ip_filter = lambda { |ip| ip == 'foo' }
    req = make_request(Rack::MockRequest.env_for("/"))
    assert req.trusted_proxy?('foo')
    Rack::Request.ip_filter = old_ip
  end

  it "regards local addresses as proxies" do
    req = make_request(Rack::MockRequest.env_for("/"))
    req.trusted_proxy?('127.0.0.1').must_equal true
    req.trusted_proxy?('127.000.000.001').must_equal true
    req.trusted_proxy?('127.0.0.6').must_equal true
    req.trusted_proxy?('127.0.0.30').must_equal true
    req.trusted_proxy?('10.0.0.1').must_equal true
    req.trusted_proxy?('10.000.000.001').must_equal true
    req.trusted_proxy?('172.16.0.1').must_equal true
    req.trusted_proxy?('172.20.0.1').must_equal true
    req.trusted_proxy?('172.30.0.1').must_equal true
    req.trusted_proxy?('172.31.0.1').must_equal true
    req.trusted_proxy?('172.31.000.001').must_equal true
    req.trusted_proxy?('192.168.0.1').must_equal true
    req.trusted_proxy?('192.168.000.001').must_equal true
    req.trusted_proxy?('::1').must_equal true
    req.trusted_proxy?('fd00::').must_equal true
    req.trusted_proxy?('FD00::').must_equal true
    req.trusted_proxy?('localhost').must_equal true
    req.trusted_proxy?('unix').must_equal true
    req.trusted_proxy?('unix:/tmp/sock').must_equal true

    req.trusted_proxy?("unix.example.org").must_equal false
    req.trusted_proxy?("example.org\n127.0.0.1").must_equal false
    req.trusted_proxy?("127.0.0.1\nexample.org").must_equal false
    req.trusted_proxy?("127.256.0.1").must_equal false
    req.trusted_proxy?("127.0.256.1").must_equal false
    req.trusted_proxy?("127.0.0.256").must_equal false
    req.trusted_proxy?('127.0.0.300').must_equal false
    req.trusted_proxy?("10.256.0.1").must_equal false
    req.trusted_proxy?("10.0.256.1").must_equal false
    req.trusted_proxy?("10.0.0.256").must_equal false
    req.trusted_proxy?("11.0.0.1").must_equal false
    req.trusted_proxy?("11.000.000.001").must_equal false
    req.trusted_proxy?("172.15.0.1").must_equal false
    req.trusted_proxy?("172.32.0.1").must_equal false
    req.trusted_proxy?("172.16.256.1").must_equal false
    req.trusted_proxy?("172.16.0.256").must_equal false
    req.trusted_proxy?("2001:470:1f0b:18f8::1").must_equal false
  end

  it "sets the default session to an empty hash" do
    req = make_request(Rack::MockRequest.env_for("http://example.com:8080/"))
    session = req.session
    assert_equal Hash.new, session
    req.env['rack.session'].must_be_same_as session
  end

  it "sets the default session options to an empty hash" do
    req = make_request(Rack::MockRequest.env_for("http://example.com:8080/"))
    session_options = req.session_options
    assert_equal Hash.new, session_options
    req.env['rack.session.options'].must_be_same_as session_options
    assert_equal Hash.new, req.session_options
  end

  class MyRequest < Rack::Request
    def params
      { foo: "bar" }
    end
  end

  it "allow subclass request to be instantiated after parent request" do
    env = Rack::MockRequest.env_for("/?foo=bar")

    req1 = make_request(env)
    req1.GET.must_equal "foo" => "bar"
    req1.params.must_equal "foo" => "bar"

    req2 = MyRequest.new(env)
    req2.GET.must_equal "foo" => "bar"
    req2.params.must_equal foo: "bar"
  end

  it "allow parent request to be instantiated after subclass request" do
    env = Rack::MockRequest.env_for("/?foo=bar")

    req1 = MyRequest.new(env)
    req1.GET.must_equal "foo" => "bar"
    req1.params.must_equal foo: "bar"

    req2 = make_request(env)
    req2.GET.must_equal "foo" => "bar"
    req2.params.must_equal "foo" => "bar"
  end

  it "raise TypeError every time if request parameters are broken" do
    broken_query = Rack::MockRequest.env_for("/?foo%5B%5D=0&foo%5Bbar%5D=1")
    req = make_request(broken_query)
    lambda{req.GET}.must_raise TypeError
    lambda{req.params}.must_raise TypeError
  end

  (0x20...0x7E).collect { |a|
    b = a.chr
    c = CGI.escape(b)
    it "not strip '#{a}' => '#{c}' => '#{b}' escaped character from parameters when accessed as string" do
      url = "/?foo=#{c}bar#{c}"
      env = Rack::MockRequest.env_for(url)
      req2 = make_request(env)
      req2.GET.must_equal "foo" => "#{b}bar#{b}"
      req2.params.must_equal "foo" => "#{b}bar#{b}"
    end
  }

  (24..27).each do |exp|
    length = 2**exp
    it "handles ASCII NUL input of #{length} bytes" do
      mr = Rack::MockRequest.env_for("/",
        "REQUEST_METHOD" => 'POST',
        :input => "\0"*length)
      req = make_request mr
      req.query_string.must_equal ""
      req.GET.must_be :empty?
      keys = req.POST.keys
      keys.length.must_equal 1
      keys.first.length.must_equal(length-1)
      keys.first.must_equal("\0"*(length-1))
    end
  end

  it "Env sets @env on initialization" do
    c = Class.new do
      include Rack::Request::Env
    end
    h = {}
    c.new(h).env.must_be_same_as h
  end

  class NonDelegate < Rack::Request
    def delegate?; false; end
  end

  def make_request(env)
    NonDelegate.new env
  end

  class TestProxyRequest < RackRequestTest
    class DelegateRequest
      include Rack::Request::Helpers
      extend Forwardable

      def_delegators :@req, :env, :has_header?, :get_header, :fetch_header,
        :each_header, :set_header, :add_header, :delete_header

      def_delegators :@req, :[], :[]=

      def initialize(req)
        @req = req
      end

      def delegate?; true; end
    end

    def make_request(env)
      DelegateRequest.new super(env)
    end
  end
end
