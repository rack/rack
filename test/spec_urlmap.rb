# frozen_string_literal: true

require_relative 'helper'

separate_testing do
  require_relative '../lib/rack/urlmap'
  require_relative '../lib/rack/lint'
  require_relative '../lib/rack/mock_request'
end

describe Rack::URLMap do
  it "dispatches paths correctly" do
    app = lambda { |env|
      [200, {
        'x-scriptname' => env['SCRIPT_NAME'],
        'x-pathinfo' => env['PATH_INFO'],
        'content-type' => 'text/plain'
      }, [""]]
    }
    map = Rack::Lint.new(Rack::URLMap.new({
      'http://foo.org/bar' => app,
      '/foo' => app,
      '/foo/bar' => app
    }))

    res = Rack::MockRequest.new(map).get("/")
    res.must_be :not_found?

    res = Rack::MockRequest.new(map).get("/qux")
    res.must_be :not_found?

    res = Rack::MockRequest.new(map).get("/foo")
    res.must_be :ok?
    res["x-scriptname"].must_equal "/foo"
    res["x-pathinfo"].must_equal ""

    res = Rack::MockRequest.new(map).get("/foo/")
    res.must_be :ok?
    res["x-scriptname"].must_equal "/foo"
    res["x-pathinfo"].must_equal "/"

    res = Rack::MockRequest.new(map).get("/foo/bar")
    res.must_be :ok?
    res["x-scriptname"].must_equal "/foo/bar"
    res["x-pathinfo"].must_equal ""

    res = Rack::MockRequest.new(map).get("/foo/bard")
    res.must_be :ok?
    res["x-scriptname"].must_equal "/foo"
    res["x-pathinfo"].must_equal "/bard"

    res = Rack::MockRequest.new(map).get("/foo/bar/")
    res.must_be :ok?
    res["x-scriptname"].must_equal "/foo/bar"
    res["x-pathinfo"].must_equal "/"

    res = Rack::MockRequest.new(map).get("/foo///bar//quux")
    res.status.must_equal 200
    res.must_be :ok?
    res["x-scriptname"].must_equal "/foo/bar"
    res["x-pathinfo"].must_equal "//quux"

    res = Rack::MockRequest.new(map).get("/foo/quux", "SCRIPT_NAME" => "/bleh")
    res.must_be :ok?
    res["x-scriptname"].must_equal "/bleh/foo"
    res["x-pathinfo"].must_equal "/quux"

    res = Rack::MockRequest.new(map).get("/bar", 'HTTP_HOST' => 'foo.org')
    res.must_be :ok?
    res["x-scriptname"].must_equal "/bar"
    res["x-pathinfo"].must_be :empty?

    res = Rack::MockRequest.new(map).get("/bar/", 'HTTP_HOST' => 'foo.org')
    res.must_be :ok?
    res["x-scriptname"].must_equal "/bar"
    res["x-pathinfo"].must_equal '/'
  end


  it "dispatches hosts correctly" do
    map = Rack::Lint.new(Rack::URLMap.new("http://foo.org/" => lambda { |env|
                             [200,
                              { "content-type" => "text/plain",
                                "x-position" => "foo.org",
                                "x-host" => env["HTTP_HOST"] || env["SERVER_NAME"],
                              }, [""]]},
                           "http://subdomain.foo.org/" => lambda { |env|
                             [200,
                              { "content-type" => "text/plain",
                                "x-position" => "subdomain.foo.org",
                                "x-host" => env["HTTP_HOST"] || env["SERVER_NAME"],
                              }, [""]]},
                           "http://bar.org/" => lambda { |env|
                             [200,
                              { "content-type" => "text/plain",
                                "x-position" => "bar.org",
                                "x-host" => env["HTTP_HOST"] || env["SERVER_NAME"],
                              }, [""]]},
                           "/" => lambda { |env|
                             [200,
                              { "content-type" => "text/plain",
                                "x-position" => "default.org",
                                "x-host" => env["HTTP_HOST"] || env["SERVER_NAME"],
                              }, [""]]}
                           ))

    res = Rack::MockRequest.new(map).get("/")
    res.must_be :ok?
    res["x-position"].must_equal "default.org"

    res = Rack::MockRequest.new(map).get("/", "HTTP_HOST" => "bar.org")
    res.must_be :ok?
    res["x-position"].must_equal "bar.org"

    res = Rack::MockRequest.new(map).get("/", "HTTP_HOST" => "foo.org")
    res.must_be :ok?
    res["x-position"].must_equal "foo.org"

    res = Rack::MockRequest.new(map).get("/", "HTTP_HOST" => "subdomain.foo.org", "SERVER_NAME" => "foo.org")
    res.must_be :ok?
    res["x-position"].must_equal "subdomain.foo.org"

    res = Rack::MockRequest.new(map).get("http://foo.org/")
    res.must_be :ok?
    res["x-position"].must_equal "foo.org"

    res = Rack::MockRequest.new(map).get("/", "HTTP_HOST" => "example.org")
    res.must_be :ok?
    res["x-position"].must_equal "default.org"

    res = Rack::MockRequest.new(map).get("/", "HTTP_HOST" => "any-host.org")
    res.must_be :ok?
    res["x-position"].must_equal "default.org"

    res = Rack::MockRequest.new(map).get("/", "HTTP_HOST" => "any-host.org", "HTTP_X_FORWARDED_HOST" => "any-host.org")
    res.must_be :ok?
    res["x-position"].must_equal "default.org"

    res = Rack::MockRequest.new(map).get("/",
                                         "HTTP_HOST" => "example.org:9292",
                                         "SERVER_PORT" => "9292")
    res.must_be :ok?
    res["x-position"].must_equal "default.org"
  end

  it "be nestable" do
    map = Rack::Lint.new(Rack::URLMap.new("/foo" =>
      Rack::URLMap.new("/bar" =>
        Rack::URLMap.new("/quux" => lambda { |env|
                           [200,
                            { "content-type" => "text/plain",
                              "x-position" => "/foo/bar/quux",
                              "x-pathinfo" => env["PATH_INFO"],
                              "x-scriptname" => env["SCRIPT_NAME"],
                            }, [""]]}
                         ))))

    res = Rack::MockRequest.new(map).get("/foo/bar")
    res.must_be :not_found?

    res = Rack::MockRequest.new(map).get("/foo/bar/quux")
    res.must_be :ok?
    res["x-position"].must_equal "/foo/bar/quux"
    res["x-pathinfo"].must_equal ""
    res["x-scriptname"].must_equal "/foo/bar/quux"
  end

  it "route root apps correctly" do
    map = Rack::Lint.new(Rack::URLMap.new("/" => lambda { |env|
                             [200,
                              { "content-type" => "text/plain",
                                "x-position" => "root",
                                "x-pathinfo" => env["PATH_INFO"],
                                "x-scriptname" => env["SCRIPT_NAME"]
                              }, [""]]},
                           "/foo" => lambda { |env|
                             [200,
                              { "content-type" => "text/plain",
                                "x-position" => "foo",
                                "x-pathinfo" => env["PATH_INFO"],
                                "x-scriptname" => env["SCRIPT_NAME"]
                              }, [""]]}
                           ))

    res = Rack::MockRequest.new(map).get("/foo/bar")
    res.must_be :ok?
    res["x-position"].must_equal "foo"
    res["x-pathinfo"].must_equal "/bar"
    res["x-scriptname"].must_equal "/foo"

    res = Rack::MockRequest.new(map).get("/foo")
    res.must_be :ok?
    res["x-position"].must_equal "foo"
    res["x-pathinfo"].must_equal ""
    res["x-scriptname"].must_equal "/foo"

    res = Rack::MockRequest.new(map).get("/bar")
    res.must_be :ok?
    res["x-position"].must_equal "root"
    res["x-pathinfo"].must_equal "/bar"
    res["x-scriptname"].must_equal ""

    res = Rack::MockRequest.new(map).get("")
    res.must_be :ok?
    res["x-position"].must_equal "root"
    res["x-pathinfo"].must_equal "/"
    res["x-scriptname"].must_equal ""
  end

  it "not squeeze slashes" do
    map = Rack::Lint.new(Rack::URLMap.new("/" => lambda { |env|
                             [200,
                              { "content-type" => "text/plain",
                                "x-position" => "root",
                                "x-pathinfo" => env["PATH_INFO"],
                                "x-scriptname" => env["SCRIPT_NAME"]
                              }, [""]]},
                           "/foo" => lambda { |env|
                             [200,
                              { "content-type" => "text/plain",
                                "x-position" => "foo",
                                "x-pathinfo" => env["PATH_INFO"],
                                "x-scriptname" => env["SCRIPT_NAME"]
                              }, [""]]}
                           ))

    res = Rack::MockRequest.new(map).get("/http://example.org/bar")
    res.must_be :ok?
    res["x-position"].must_equal "root"
    res["x-pathinfo"].must_equal "/http://example.org/bar"
    res["x-scriptname"].must_equal ""
  end

  it "not be case sensitive with hosts" do
    map = Rack::Lint.new(Rack::URLMap.new("http://example.org/" => lambda { |env|
                             [200,
                              { "content-type" => "text/plain",
                                "x-position" => "root",
                                "x-pathinfo" => env["PATH_INFO"],
                                "x-scriptname" => env["SCRIPT_NAME"]
                              }, [""]]}
                           ))

    res = Rack::MockRequest.new(map).get("http://example.org/")
    res.must_be :ok?
    res["x-position"].must_equal "root"
    res["x-pathinfo"].must_equal "/"
    res["x-scriptname"].must_equal ""

    res = Rack::MockRequest.new(map).get("http://EXAMPLE.ORG/")
    res.must_be :ok?
    res["x-position"].must_equal "root"
    res["x-pathinfo"].must_equal "/"
    res["x-scriptname"].must_equal ""
  end

  it "not allow locations unless they start with /" do
    lambda do
      Rack::URLMap.new("a/" => lambda { |env| })
    end.must_raise ArgumentError
  end
end
