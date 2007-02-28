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
    req.query_string.should.equal ""

    req.host.should.equal "example.org"
    req.port.should.equal 8080
  end

  specify "can figure out the correct host" do
    req = Rack::Request.new(TestRequest.env({"HTTP_HOST" => "www2.example.org"}))
    req.host.should.equal "www2.example.org"

    req = Rack::Request.new(TestRequest.env({"SERVER_NAME" => "example.org:9292"}))
    req.host.should.equal "example.org"
  end

  specify "can parse the query string" do
    req = Rack::Request.new(TestRequest.env("QUERY_STRING"=>"foo=bar&quux=bla"))
    req.query_string.should.equal "foo=bar&quux=bla"
    req.GET.should.equal "foo" => "bar", "quux" => "bla"
    req.POST.should.be.empty
    req.params.should.equal "foo" => "bar", "quux" => "bla"
  end

  specify "can parse POST data" do
    req = Rack::Request.new(TestRequest.env("QUERY_STRING"=>"foo=quux",
                              "rack.input" => StringIO.new("foo=bar&quux=bla")))
    req.query_string.should.equal "foo=quux"
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

  specify "can parse multipart form data" do
    # Adapted from RFC 1867.
    input = StringIO.new(<<EOF)
--AaB03x\r
content-disposition: form-data; name="reply"\r
\r
yes\r
--AaB03x\r
content-disposition: form-data; name="fileupload"; filename="dj.jpg"\r
Content-Type: image/jpeg\r
Content-Transfer-Encoding: base64\r
\r
/9j/4AAQSkZJRgABAQAAAQABAAD//gA+Q1JFQVRPUjogZ2QtanBlZyB2MS4wICh1c2luZyBJSkcg\r
--AaB03x--\r
EOF
    input.rewind
    req = Rack::Request.new \
    TestRequest.env("CONTENT_TYPE" => "multipart/form-data, boundary=AaB03x",
                    "CONTENT_LENGTH" => input.size,
                      "rack.input" => input)

    req.POST.should.include "fileupload"
    req.POST.should.include "reply"

    req.POST["reply"].should.equal "yes"

    f = req.POST["fileupload"]
    f.should.be.kind_of Hash
    f[:type].should.equal "image/jpeg"
    f[:filename].should.equal "dj.jpg"
    f.should.include :tempfile
    f[:tempfile].size.should.equal 76
  end

  specify "can parse big multipart form data" do
    input = StringIO.new(<<EOF)
--AaB03x\r
content-disposition: form-data; name="huge"; filename="huge"\r
\r
#{"x"*32768}\r
--AaB03x\r
content-disposition: form-data; name="mean"; filename="mean"\r
\r
--AaB03xha\r
--AaB03x--\r
EOF
    input.rewind
    req = Rack::Request.new \
    TestRequest.env("CONTENT_TYPE" => "multipart/form-data, boundary=AaB03x",
                    "CONTENT_LENGTH" => input.size,
                      "rack.input" => input)
    
    req.POST["huge"][:tempfile].size.should.equal 32768
    req.POST["mean"][:tempfile].size.should.equal 10
    req.POST["mean"][:tempfile].read.should.equal "--AaB03xha"
  end

  specify "can detect invalid multipart form data" do
    input = StringIO.new(<<EOF)
--AaB03x\r
content-disposition: form-data; name="huge"; filename="huge"\r
EOF
    input.rewind
    req = Rack::Request.new \
    TestRequest.env("CONTENT_TYPE" => "multipart/form-data, boundary=AaB03x",
                    "CONTENT_LENGTH" => input.size,
                    "rack.input" => input)

    lambda { req.POST }.should.raise(EOFError)

    input = StringIO.new(<<EOF)
--AaB03x\r
content-disposition: form-data; name="huge"; filename="huge"\r
\r
foo\r
EOF
    input.rewind
    req = Rack::Request.new \
    TestRequest.env("CONTENT_TYPE" => "multipart/form-data, boundary=AaB03x",
                    "CONTENT_LENGTH" => input.size,
                    "rack.input" => input)

    lambda { req.POST }.should.raise(EOFError)

    input = StringIO.new(<<EOF)
--AaB03x\r
content-disposition: form-data; name="huge"; filename="huge"\r
\r
foo\r
EOF
    input.rewind
    req = Rack::Request.new \
    TestRequest.env("CONTENT_TYPE" => "multipart/form-data, boundary=AaB03x",
                    "CONTENT_LENGTH" => input.size,
                    "rack.input" => input)

    lambda { req.POST }.should.raise(EOFError)
  end
end
