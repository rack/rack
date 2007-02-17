require 'test/spec'

require 'rack/urlmap'
require 'rack/testrequest'

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
                              }, [""]]},
                           
                           "/foo/bar" => lambda { |env|
                             [200,
                              { "Content-Type" => "text/plain",
                                "X-Position" => "/foo/bar", 
                                "X-PathInfo" => env["PATH_INFO"],
                              }, [""]]}
                           )

    
    status, headers, _ = map.call(TestRequest.env({}))
    status.should.equal 404

    status, headers, _ = map.call(TestRequest.env({"PATH_INFO" => "/foo"}))
    status.should.equal 200
    headers["X-Position"].should.equal "/foo"
    headers["X-PathInfo"].should.equal "/"

    status, headers, _ = map.call(TestRequest.env({"PATH_INFO" => "/bar"}))
    status.should.equal 200
    headers["X-Position"].should.equal "/bar"
    headers["X-PathInfo"].should.equal "/"

    status, headers, _ = map.call(TestRequest.env({"SCRIPT_NAME" => "/foo"}))
    status.should.equal 200
    headers["X-Position"].should.equal "/foo"
    headers["X-PathInfo"].should.equal "/"

    status, headers, _ = map.call(TestRequest.env({"SCRIPT_NAME" => "/foo",
                                                  "PATH_INFO" => "/quux"}))
    status.should.equal 200
    headers["X-Position"].should.equal "/foo"
    headers["X-PathInfo"].should.equal "/quux"

    status, headers, _ = map.call(TestRequest.env({"SCRIPT_NAME" => "/",
                                                  "PATH_INFO" => "/foo/quux"}))
    status.should.equal 200
    headers["X-Position"].should.equal "/foo"
    headers["X-PathInfo"].should.equal "/quux"

    status, headers, _ = map.call(TestRequest.env({"SCRIPT_NAME" => "/foo/quux",
                                                  "PATH_INFO" => nil}))
    status.should.equal 200
    headers["X-Position"].should.equal "/foo"
    headers["X-PathInfo"].should.equal "/quux"

    status, headers, _ = map.call(TestRequest.env({"SCRIPT_NAME" => "/foo/bar",
                                                  "PATH_INFO" => nil}))
    status.should.equal 200
    headers["X-Position"].should.equal "/foo/bar"
    headers["X-PathInfo"].should.equal "/"
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

    status, headers, _ = map.call(TestRequest.env({"SCRIPT_NAME" => "/"}))
    status.should.equal 200
    headers["X-Position"].should.equal "default.org"

    status, headers, _ = map.call(TestRequest.env({"SCRIPT_NAME" => "/",
                                                  "HTTP_HOST" => "bar.org"}))
    status.should.equal 200
    headers["X-Position"].should.equal "bar.org"

    status, headers, _ = map.call(TestRequest.env({"SCRIPT_NAME" => "/",
                                                  "HTTP_HOST" => "foo.org"}))
    status.should.equal 200
    headers["X-Position"].should.equal "foo.org"

    status, headers, _ = map.call(TestRequest.env({"SCRIPT_NAME" => "/",
                                                  "SERVER_NAME" => "foo.org"}))
    status.should.equal 200
    headers["X-Position"].should.equal "default.org"

    status, headers, _ = map.call(TestRequest.env({"SCRIPT_NAME" => "/",
                                                  "HTTP_HOST" => "example.org"}))
    status.should.equal 200
    headers["X-Position"].should.equal "default.org"
  end
end
