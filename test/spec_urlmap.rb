require 'rack/urlmap'
require 'rack/mock'

describe Rack::URLMap do
  it "dispatches paths correctly" do
    app = lambda { |env|
      [200, {
        'X-ScriptName' => env['SCRIPT_NAME'],
        'X-PathInfo' => env['PATH_INFO'],
        'Content-Type' => 'text/plain'
      }, [""]]
    }
    map = Rack::Lint.new(Rack::URLMap.new({
      'http://foo.org/bar' => app,
      '/foo' => app,
      '/foo/bar' => app
    }))

    res = Rack::MockRequest.new(map).get("/")
    res.should.be.not_found

    res = Rack::MockRequest.new(map).get("/qux")
    res.should.be.not_found

    res = Rack::MockRequest.new(map).get("/foo")
    res.should.be.ok
    res["X-ScriptName"].should.equal "/foo"
    res["X-PathInfo"].should.equal ""

    res = Rack::MockRequest.new(map).get("/foo/")
    res.should.be.ok
    res["X-ScriptName"].should.equal "/foo"
    res["X-PathInfo"].should.equal "/"

    res = Rack::MockRequest.new(map).get("/foo/bar")
    res.should.be.ok
    res["X-ScriptName"].should.equal "/foo/bar"
    res["X-PathInfo"].should.equal ""

    res = Rack::MockRequest.new(map).get("/foo/bar/")
    res.should.be.ok
    res["X-ScriptName"].should.equal "/foo/bar"
    res["X-PathInfo"].should.equal "/"

    res = Rack::MockRequest.new(map).get("/foo///bar//quux")
    res.status.should.equal 200
    res.should.be.ok
    res["X-ScriptName"].should.equal "/foo/bar"
    res["X-PathInfo"].should.equal "//quux"

    res = Rack::MockRequest.new(map).get("/foo/quux", "SCRIPT_NAME" => "/bleh")
    res.should.be.ok
    res["X-ScriptName"].should.equal "/bleh/foo"
    res["X-PathInfo"].should.equal "/quux"

    res = Rack::MockRequest.new(map).get("/bar", 'HTTP_HOST' => 'foo.org')
    res.should.be.ok
    res["X-ScriptName"].should.equal "/bar"
    res["X-PathInfo"].should.be.empty

    res = Rack::MockRequest.new(map).get("/bar/", 'HTTP_HOST' => 'foo.org')
    res.should.be.ok
    res["X-ScriptName"].should.equal "/bar"
    res["X-PathInfo"].should.equal '/'
  end


  it "dispatches hosts correctly" do
    map = Rack::Lint.new(Rack::URLMap.new("http://foo.org/" => lambda { |env|
                             [200,
                              { "Content-Type" => "text/plain",
                                "X-Position" => "foo.org",
                                "X-Host" => env["HTTP_HOST"] || env["SERVER_NAME"],
                              }, [""]]},
                           "http://subdomain.foo.org/" => lambda { |env|
                             [200,
                              { "Content-Type" => "text/plain",
                                "X-Position" => "subdomain.foo.org",
                                "X-Host" => env["HTTP_HOST"] || env["SERVER_NAME"],
                              }, [""]]},
                           "http://bar.org/" => lambda { |env|
                             [200,
                              { "Content-Type" => "text/plain",
                                "X-Position" => "bar.org",
                                "X-Host" => env["HTTP_HOST"] || env["SERVER_NAME"],
                              }, [""]]},
                           "/" => lambda { |env|
                             [200,
                              { "Content-Type" => "text/plain",
                                "X-Position" => "default.org",
                                "X-Host" => env["HTTP_HOST"] || env["SERVER_NAME"],
                              }, [""]]}
                           ))

    res = Rack::MockRequest.new(map).get("/")
    res.should.be.ok
    res["X-Position"].should.equal "default.org"

    res = Rack::MockRequest.new(map).get("/", "HTTP_HOST" => "bar.org")
    res.should.be.ok
    res["X-Position"].should.equal "bar.org"

    res = Rack::MockRequest.new(map).get("/", "HTTP_HOST" => "foo.org")
    res.should.be.ok
    res["X-Position"].should.equal "foo.org"

    res = Rack::MockRequest.new(map).get("/", "HTTP_HOST" => "subdomain.foo.org", "SERVER_NAME" => "foo.org")
    res.should.be.ok
    res["X-Position"].should.equal "subdomain.foo.org"

    res = Rack::MockRequest.new(map).get("http://foo.org/")
    res.should.be.ok
    res["X-Position"].should.equal "default.org"

    res = Rack::MockRequest.new(map).get("/", "HTTP_HOST" => "example.org")
    res.should.be.ok
    res["X-Position"].should.equal "default.org"

    res = Rack::MockRequest.new(map).get("/",
                                         "HTTP_HOST" => "example.org:9292",
                                         "SERVER_PORT" => "9292")
    res.should.be.ok
    res["X-Position"].should.equal "default.org"
  end

  should "be nestable" do
    map = Rack::Lint.new(Rack::URLMap.new("/foo" =>
      Rack::URLMap.new("/bar" =>
        Rack::URLMap.new("/quux" =>  lambda { |env|
                           [200,
                            { "Content-Type" => "text/plain",
                              "X-Position" => "/foo/bar/quux",
                              "X-PathInfo" => env["PATH_INFO"],
                              "X-ScriptName" => env["SCRIPT_NAME"],
                            }, [""]]}
                         ))))

    res = Rack::MockRequest.new(map).get("/foo/bar")
    res.should.be.not_found

    res = Rack::MockRequest.new(map).get("/foo/bar/quux")
    res.should.be.ok
    res["X-Position"].should.equal "/foo/bar/quux"
    res["X-PathInfo"].should.equal ""
    res["X-ScriptName"].should.equal "/foo/bar/quux"
  end

  should "route root apps correctly" do
    map = Rack::Lint.new(Rack::URLMap.new("/" => lambda { |env|
                             [200,
                              { "Content-Type" => "text/plain",
                                "X-Position" => "root",
                                "X-PathInfo" => env["PATH_INFO"],
                                "X-ScriptName" => env["SCRIPT_NAME"]
                              }, [""]]},
                           "/foo" => lambda { |env|
                             [200,
                              { "Content-Type" => "text/plain",
                                "X-Position" => "foo",
                                "X-PathInfo" => env["PATH_INFO"],
                                "X-ScriptName" => env["SCRIPT_NAME"]
                              }, [""]]}
                           ))

    res = Rack::MockRequest.new(map).get("/foo/bar")
    res.should.be.ok
    res["X-Position"].should.equal "foo"
    res["X-PathInfo"].should.equal "/bar"
    res["X-ScriptName"].should.equal "/foo"

    res = Rack::MockRequest.new(map).get("/foo")
    res.should.be.ok
    res["X-Position"].should.equal "foo"
    res["X-PathInfo"].should.equal ""
    res["X-ScriptName"].should.equal "/foo"

    res = Rack::MockRequest.new(map).get("/bar")
    res.should.be.ok
    res["X-Position"].should.equal "root"
    res["X-PathInfo"].should.equal "/bar"
    res["X-ScriptName"].should.equal ""

    res = Rack::MockRequest.new(map).get("")
    res.should.be.ok
    res["X-Position"].should.equal "root"
    res["X-PathInfo"].should.equal "/"
    res["X-ScriptName"].should.equal ""
  end

  should "not squeeze slashes" do
    map = Rack::Lint.new(Rack::URLMap.new("/" => lambda { |env|
                             [200,
                              { "Content-Type" => "text/plain",
                                "X-Position" => "root",
                                "X-PathInfo" => env["PATH_INFO"],
                                "X-ScriptName" => env["SCRIPT_NAME"]
                              }, [""]]},
                           "/foo" => lambda { |env|
                             [200,
                              { "Content-Type" => "text/plain",
                                "X-Position" => "foo",
                                "X-PathInfo" => env["PATH_INFO"],
                                "X-ScriptName" => env["SCRIPT_NAME"]
                              }, [""]]}
                           ))

    res = Rack::MockRequest.new(map).get("/http://example.org/bar")
    res.should.be.ok
    res["X-Position"].should.equal "root"
    res["X-PathInfo"].should.equal "/http://example.org/bar"
    res["X-ScriptName"].should.equal ""
  end

  should "handle named parameters in URL" do
    app = lambda { |env|
      [200, {
        "X-URLParams" => env["rack.url_params"],
        "Content-Type" => "text/plain"
      }, [""]]
    }
    map = Rack::URLMap.new({
      "/foo" => app,
      "/foo/:bar" => app,
      "/foo/:bar/baz" => app,
      "/foo/:bar/baz/:qux" => app
    })

    res = Rack::MockRequest.new(map).get("/foo")
    res.should.be.ok
    res["X-URLParams"].should.equal({})

    res = Rack::MockRequest.new(map).get("/foo/2")
    res.should.be.ok
    res["X-URLParams"].should.equal({:bar=>"2"})

    res = Rack::MockRequest.new(map).get("/foo/2/baz")
    res.should.be.ok
    res["X-URLParams"].should.equal({:bar=>"2"})

    res = Rack::MockRequest.new(map).get("/foo/2/baz/four")
    res.should.be.ok
    res["X-URLParams"].should.equal({:bar=>"2",:qux=>"four"})
  end

  should "prioritize named parameters in URL correctly" do
    app1 = lambda { |env|
      [200, {
        "Content-Type" => "text/plain"
      }, ["app1"]]
    }
    app2 = lambda { |env|
      [200, {
        "Content-Type" => "text/plain"
      }, ["app2"]]
    }

    map1 = Rack::URLMap.new({
      "/foo/baaaaar" => app1,
      "/foo/:short"  => app2
    })

    map2 = Rack::URLMap.new({
      "/foo/baaaaar"       => app1,
      "/foo/:looooooooong" => app2
    })

    res = Rack::MockRequest.new(map1).get("/foo/baaaaar")
    res.should.be.ok
    res.body.should.equal 'app1' # <= as expected

    res = Rack::MockRequest.new(map1).get("/foo/not-bar")
    res.should.be.ok
    res.body.should.equal 'app2' # <= as expected

    res = Rack::MockRequest.new(map2).get("/foo/baaaaar")
    res.should.be.ok
    res.body.should.equal 'app1' # <= fails!

    res = Rack::MockRequest.new(map2).get("/foo/not-bar")
    res.should.be.ok
    res.body.should.equal 'app2' # <= as expected

  end
end
