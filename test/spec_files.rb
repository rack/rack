# frozen_string_literal: true

require_relative 'helper'

separate_testing do
  require_relative '../lib/rack/files'
  require_relative '../lib/rack/lint'
  require_relative '../lib/rack/mock_request'
end

describe Rack::Files do
  DOCROOT = File.expand_path(File.dirname(__FILE__)) unless defined? DOCROOT

  def files(*args)
    Rack::Lint.new Rack::Files.new(*args)
  end

  it "can be used without root" do
    # https://github.com/rack/rack/issues/1464

    app = Rack::Files.new(nil)

    request = Rack::Request.new(
      Rack::MockRequest.env_for("/cgi/test")
    )

    file_path = File.expand_path("cgi/test", __dir__)
    assert_equal 200, app.serving(request, file_path)[0]
  end

  it 'serves files with + in the file name' do
    Dir.mktmpdir do |dir|
      File.write File.join(dir, "you+me.txt"), "hello world"
      app = files(dir)
      env = Rack::MockRequest.env_for("/you+me.txt")
      status, _, body = app.call env

      assert_equal 200, status

      str = ''.dup
      body.each { |x| str << x }
      assert_match "hello world", str
    end
  end

  it "serves the correct file content for a GET request" do
    res = Rack::MockRequest.new(files(DOCROOT)).get("/cgi/test")

    res.must_be :ok?
    assert_match(res, /ruby/)
  end

  it "does not serve directories" do
    res = Rack::MockRequest.new(files(DOCROOT)).get("/cgi/assets")
    res.status.must_equal 404
  end

  it "sets the last-modified header" do
    res = Rack::MockRequest.new(files(DOCROOT)).get("/cgi/test")

    path = File.join(DOCROOT, "/cgi/test")

    res.must_be :ok?
    res["last-modified"].must_equal File.mtime(path).httpdate
  end

  it "returns 304 if file isn't modified since last serve" do
    path = File.join(DOCROOT, "/cgi/test")
    res = Rack::MockRequest.new(files(DOCROOT)).
      get("/cgi/test", 'HTTP_IF_MODIFIED_SINCE' => File.mtime(path).httpdate)

    res.status.must_equal 304
    res.body.must_be :empty?
  end

  it "returns the file if it has been modified since last serve" do
    path = File.join(DOCROOT, "/cgi/test")
    res = Rack::MockRequest.new(files(DOCROOT)).
      get("/cgi/test", 'HTTP_IF_MODIFIED_SINCE' => (File.mtime(path) - 100).httpdate)

    res.must_be :ok?
  end

  it "serves files with URL encoded filenames" do
    res = Rack::MockRequest.new(files(DOCROOT)).get("/cgi/%74%65%73%74") # "/cgi/test"

    res.must_be :ok?
    # res.must_match(/ruby/)    # nope
    # (/ruby/).must_match res   # This is weird, but an oddity of minitest
    # assert_match(/ruby/, res) # nope
    assert_match(res, /ruby/)
  end

  it "serves uri with URL encoded null byte (%00) in filenames" do
    res = Rack::MockRequest.new(files(DOCROOT)).get("/cgi/test%00")
    res.must_be :bad_request?
  end

  it "allows safe directory traversal" do
    req = Rack::MockRequest.new(files(DOCROOT))

    res = req.get('/cgi/../cgi/test')
    res.must_be :successful?

    res = req.get('.')
    res.must_be :not_found?

    res = req.get("test/..")
    res.must_be :not_found?
  end

  it "does not allow unsafe directory traversal" do
    req = Rack::MockRequest.new(files(DOCROOT))

    res = req.get("/../README.rdoc")
    res.must_be :client_error?

    res = req.get("../test/spec_file.rb")
    res.must_be :client_error?

    res = req.get("../README.rdoc")
    res.must_be :client_error?

    res.must_be :not_found?
  end

  it "allows files with .. in their name" do
    req = Rack::MockRequest.new(files(DOCROOT))
    res = req.get("/cgi/..test")
    res.must_be :not_found?

    res = req.get("/cgi/test..")
    res.must_be :not_found?

    res = req.get("/cgi../test..")
    res.must_be :not_found?
  end

  it "does not allow unsafe directory traversal with encoded periods" do
    res = Rack::MockRequest.new(files(DOCROOT)).get("/%2E%2E/README")

    res.must_be :client_error?
    res.must_be :not_found?
  end

  it "allows safe directory traversal with encoded periods" do
    res = Rack::MockRequest.new(files(DOCROOT)).get("/cgi/%2E%2E/cgi/test")

    res.must_be :successful?
  end

  it "returns 404 if it can't find the file" do
    res = Rack::MockRequest.new(files(DOCROOT)).get("/cgi/blubb")

    res.must_be :not_found?
  end

  it "detects SystemCallErrors" do
    res = Rack::MockRequest.new(files(DOCROOT)).get("/cgi")

    res.must_be :not_found?
  end

  it "returns bodies that respond to #to_path" do
    env = Rack::MockRequest.env_for("/cgi/test")
    status, _, body = Rack::Files.new(DOCROOT).call(env)

    path = File.join(DOCROOT, "/cgi/test")

    status.must_equal 200
    body.must_respond_to :to_path
    body.to_path.must_equal path
  end

  it "returns bodies that do not respond to #to_path if a byte range is requested" do
    env = Rack::MockRequest.env_for("/cgi/test")
    env["HTTP_RANGE"] = "bytes=22-33"
    status, _, body = Rack::Files.new(DOCROOT).call(env)

    status.must_equal 206
    body.wont_respond_to :to_path
  end

  it "returns correct byte range in body" do
    env = Rack::MockRequest.env_for("/cgi/test")
    env["HTTP_RANGE"] = "bytes=22-33"
    res = Rack::MockResponse.new(*files(DOCROOT).call(env))

    res.status.must_equal 206
    res["content-length"].must_equal "12"
    res["content-range"].must_equal "bytes 22-33/209"
    res.body.must_equal "IS FILE! ***"
  end

  it "handles cases where the file is truncated during request" do
    env = Rack::MockRequest.env_for("/cgi/test")
    env["HTTP_RANGE"] = "bytes=0-3300"
    files = Class.new(Rack::Files) do
      def filesize(_); 10000 end
    end.new(DOCROOT)

    res = Rack::MockResponse.new(*files.call(env))
    res.status.must_equal 206
    res.length.must_equal 209
    res.finish

    res["content-length"].must_equal "209"
    res["content-range"].must_equal "bytes 0-3300/10000"
  end

  it "returns correct multiple byte ranges in body" do
    env = Rack::MockRequest.env_for("/cgi/test")
    env["HTTP_RANGE"] = "bytes=22-33, 60-80"
    res = Rack::MockResponse.new(*files(DOCROOT).call(env))

    res.status.must_equal 206
    res["content-length"].must_equal "191"
    res["content-type"].must_equal "multipart/byteranges; boundary=AaB03x"
    expected_body = <<-EOF
\r
--AaB03x\r
content-type: text/plain\r
content-range: bytes 22-33/209\r
\r
IS FILE! ***\r
--AaB03x\r
content-type: text/plain\r
content-range: bytes 60-80/209\r
\r
, tests will break!!!\r
--AaB03x--\r
    EOF

    res.body.must_equal expected_body
  end

  it "returns 416 error and correct Content-Range for unsatisfiable byte range" do
    env = Rack::MockRequest.env_for("/cgi/test")
    env["HTTP_RANGE"] = "bytes=1234-5678"
    res = Rack::MockResponse.new(*files(DOCROOT).call(env))

    res.status.must_equal 416
    res["content-range"].must_equal "bytes */209"
  end

  it "ignores range when file size is 0 bytes" do
    env = Rack::MockRequest.env_for("/cgi/assets/images/favicon.ico")
    env["HTTP_RANGE"] = "bytes=0-1234"
    res = Rack::MockResponse.new(*files(DOCROOT).call(env))

    res.status.must_equal 200
    res["content-range"].must_be_nil
  end

  it "supports custom http headers" do
    env = Rack::MockRequest.env_for("/cgi/test")
    status, heads, _ = files(DOCROOT, 'cache-control' => 'public, max-age=38',
     'access-control-allow-origin' => '*').call(env)

    status.must_equal 200
    heads['cache-control'].must_equal 'public, max-age=38'
    heads['access-control-allow-origin'].must_equal '*'
  end

  it "does not add custom HTTP headers when none are supplied" do
    env = Rack::MockRequest.env_for("/cgi/test")
    status, heads, _ = files(DOCROOT).call(env)

    status.must_equal 200
    heads['cache-control'].must_be_nil
    heads['access-control-allow-origin'].must_be_nil
  end

  it "only supports GET, HEAD, and OPTIONS requests" do
    req = Rack::MockRequest.new(files(DOCROOT))

    forbidden = %w[post put patch delete]
    forbidden.each do |method|
      res = req.send(method, "/cgi/test")
      res.must_be :client_error?
      res.must_be :method_not_allowed?
      res.headers['allow'].split(/, */).sort.must_equal %w(GET HEAD OPTIONS)
    end

    allowed = %w[get head options]
    allowed.each do |method|
      res = req.send(method, "/cgi/test")
      res.must_be :successful?
    end
  end

  it "sets Allow correctly for OPTIONS requests" do
    req = Rack::MockRequest.new(files(DOCROOT))
    res = req.options('/cgi/test')
    res.must_be :successful?
    res.headers['allow'].wont_equal nil
    res.headers['allow'].split(/, */).sort.must_equal %w(GET HEAD OPTIONS)
  end

  it "sets content-length correctly for HEAD requests" do
    req = Rack::MockRequest.new(Rack::Lint.new(Rack::Files.new(DOCROOT)))
    res = req.head "/cgi/test"
    res.must_be :successful?
    res['content-length'].must_equal "209"
  end

  it "defaults to a MIME type of text/plain" do
    req = Rack::MockRequest.new(Rack::Lint.new(Rack::Files.new(DOCROOT)))
    res = req.get "/cgi/test"
    res.must_be :successful?
    res['content-type'].must_equal "text/plain"
  end

  it "allows the default MIME type to be set" do
    req = Rack::MockRequest.new(Rack::Lint.new(Rack::Files.new(DOCROOT, nil, 'application/octet-stream')))
    res = req.get "/cgi/test"
    res.must_be :successful?
    res['content-type'].must_equal "application/octet-stream"
  end

  it "does not set the content-type header if the MIME type is not specified" do
    req = Rack::MockRequest.new(Rack::Lint.new(Rack::Files.new(DOCROOT, nil, nil)))
    res = req.get "/cgi/test"
    res.must_be :successful?
    res['content-type'].must_be_nil
  end

  it "returns 404 and empty body for a HEAD request when the file is not found" do
    res = Rack::MockRequest.new(files(DOCROOT)).head("/cgi/missing")
    res.must_be :not_found?
    res.body.must_be :empty?
  end
end
