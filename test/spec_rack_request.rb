require 'test/spec'
require 'stringio'

require 'rack/testrequest'
require 'rack/request'

context "Rack::Request" do
  specify "wraps the rack variables" do
    req = Rack::Request.new(TestRequest.env({}))

    req.body.should.respond_to? :gets
    req.scheme.should.equal "http"
    req.request_method.should.equal "GET"

    req.should.be.get
    req.should.not.be.post
    req.should.not.be.put
    req.should.not.be.delete

    req.script_name.should.equal ""
    req.path_info.should.equal "/"
    req.host.should.equal "example.org"
    req.port.should.equal 8080
  end

  specify "can figure out the correct host" do
    req = Rack::Request.new(TestRequest.env({"HTTP_HOST" => "www2.example.org"}))
    req.host.should.equal "www2.example.org"
  end

  specify "can parse the query string" do
    req = Rack::Request.new(TestRequest.env("QUERY_STRING"=>"foo=bar&quux=bla"))
    req.GET.should.equal "foo" => "bar", "quux" => "bla"
    req.POST.should.be.empty
    req.params.should.equal "foo" => "bar", "quux" => "bla"
  end

  specify "can parse POST data" do
    req = Rack::Request.new(TestRequest.env("QUERY_STRING"=>"foo=quux",
                              "rack.input" => StringIO.new("foo=bar&quux=bla")))
    req.GET.should.equal "foo" => "quux"
    req.POST.should.equal "foo" => "bar", "quux" => "bla"
    req.params.should.equal "foo" => "bar", "quux" => "bla"
  end


  specify "can cache, but invalidates the cache" do
    req = Rack::Request.new(TestRequest.env("QUERY_STRING"=>"foo=quux",
                              "rack.input" => StringIO.new("foo=bar&quux=bla")))
    req.GET.should.equal "foo" => "quux"
    req.GET.should.equal "foo" => "quux"
    req.env["QUERY_STRING"] = "bla=foo"
    req.GET.should.equal "bla" => "foo"
    req.GET.should.equal "bla" => "foo"

    req.POST.should.equal "foo" => "bar", "quux" => "bla"
    req.POST.should.equal "foo" => "bar", "quux" => "bla"
    req.env["rack.input"] = StringIO.new("foo=bla&quux=bar")
    req.POST.should.equal "foo" => "bla", "quux" => "bar"
    req.POST.should.equal "foo" => "bla", "quux" => "bar"
  end

  specify "can figure out if called via XHR" do
    req = Rack::Request.new(TestRequest.env({}))
    req.should.not.be.xhr

    req = Rack::Request.new(TestRequest.env("HTTP_X_REQUESTED_WITH" => "XMLHttpRequest"))
    req.should.be.xhr
  end

  specify "can parse cookies" do
    req = Rack::Request.new(TestRequest.env({"HTTP_COOKIE" => "foo=bar;quux=h&m"}))
    req.cookies.should.equal "foo" => "bar", "quux" => "h&m"
    req.cookies.should.equal "foo" => "bar", "quux" => "h&m"
    req.env.delete("HTTP_COOKIE")
    req.cookies.should.equal({})
  end

  specify "provides setters" do
    req = Rack::Request.new(e=TestRequest.env({}))
    req.script_name.should.equal ""
    req.script_name = "/foo"
    req.script_name.should.equal "/foo"
    e["SCRIPT_NAME"].should.equal "/foo"

    req.path_info.should.equal "/"
    req.path_info = "/foo"
    req.path_info.should.equal "/foo"
    e["PATH_INFO"].should.equal "/foo"
  end

  specify "provides the original env" do
    req = Rack::Request.new(e=TestRequest.env({}))
    req.env.should.be e
  end

  specify "can restore the URL" do
    Rack::Request.new(TestRequest.env({})).url.
      should.equal "http://example.org:8080/"
    Rack::Request.new(TestRequest.env({"SCRIPT_NAME" => "/foo"})).url.
      should.equal "http://example.org:8080/foo/"
    Rack::Request.new(TestRequest.env({"PATH_INFO" => "/foo"})).url.
      should.equal "http://example.org:8080/foo"
    Rack::Request.new(TestRequest.env({"QUERY_STRING" => "foo"})).url.
      should.equal "http://example.org:8080/?foo"
    Rack::Request.new(TestRequest.env({"SERVER_PORT" => "80"})).url.
      should.equal "http://example.org/"
    Rack::Request.new(TestRequest.env({"SERVER_PORT" => "443",
                                        "rack.url_scheme" => "https"})).url.
      should.equal "https://example.org/"
  end
end
