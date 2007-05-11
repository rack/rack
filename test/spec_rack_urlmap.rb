require 'test/spec'

require 'rack/urlmap'
require 'rack/mock'

context "Rack::URLMap" do
  specify "dispatches paths correctly" do
    map = Rack::URLMap.new("/foo" => lambda { |env|
                             [200,
                              { "Content-Type" => "text/plain",
                                "X-Position" => "/foo",
                                "X-PathInfo" => env["PATH_INFO"],
                              }, [""]]},
                           
                           "/bar" => lambda { |env|
                             [200,
                              { "Content-Type" => "text/plain",
                                "X-Position" => "/bar",
                                "X-PathInfo" => env["PATH_INFO"],
                              }, [""]]}
                           
                           )

    
    Rack::MockRequest.new(map).get("/").should.be.not_found

    res = Rack::MockRequest.new(map).get("/foo")
    res.should.be.ok
    res["X-Position"].should.equal "/foo"
    res["X-PathInfo"].should.equal "/"


    res = Rack::MockRequest.new(map).get("/bar")
    res.should.be.ok
    res["X-Position"].should.equal "/bar"
    res["X-PathInfo"].should.equal "/"

    res = Rack::MockRequest.new(map).get("/foo/quux")
    res.should.be.ok
    res["X-Position"].should.equal "/foo"
    res["X-PathInfo"].should.equal "/quux"

    res = Rack::MockRequest.new(map).get("/foo/quux", "SCRIPT_NAME" => "/bleh")
    res.should.be.ok
    res["X-Position"].should.equal "/foo"
    res["X-PathInfo"].should.equal "/quux"
  end

  specify "dispatches hosts correctly" do
    map = Rack::URLMap.new("http://foo.org/" => lambda { |env|
                             [200,
                              { "Content-Type" => "text/plain",
                                "X-Position" => "foo.org",
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
                           )

    res = Rack::MockRequest.new(map).get("/")
    res.should.be.ok
    res["X-Position"].should.equal "default.org"

    res = Rack::MockRequest.new(map).get("/", "HTTP_HOST" => "bar.org")
    res.should.be.ok
    res["X-Position"].should.equal "bar.org"

    res = Rack::MockRequest.new(map).get("/", "HTTP_HOST" => "foo.org")
    res.should.be.ok
    res["X-Position"].should.equal "foo.org"

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

  specify "should be nestable" do
    map = Rack::URLMap.new("/foo" =>
                           Rack::URLMap.new("/bar" =>  lambda { |env|
                                              [200,
                                               { "Content-Type" => "text/plain",
                                                 "X-Position" => "/foo/bar",
                                                 "X-PathInfo" => env["PATH_INFO"],
                                               }, [""]]}
                                            )
                           )

    res = Rack::MockRequest.new(map).get("/foo/bar")
    res.should.be.ok
    res["X-Position"].should.equal "/foo/bar"
  end

  specify "should route root apps correctly" do
    map = Rack::URLMap.new("/" => lambda { |env|
                             [200,
                              { "Content-Type" => "text/plain",
                                "X-Position" => "root",
                              }, [""]]},
                           "/foo" => lambda { |env|
                             [200,
                              { "Content-Type" => "text/plain",
                                "X-Position" => "foo",
                              }, [""]]}
                           )

    res = Rack::MockRequest.new(map).get("/foo/bar")
    res.should.be.ok
    res["X-Position"].should.equal "foo"

    res = Rack::MockRequest.new(map).get("/bar")
    res.should.be.ok
    res["X-Position"].should.equal "root"
  end
end
