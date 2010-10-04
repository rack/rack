require 'rack/file'
require 'rack/mock'

describe Rack::File do
  DOCROOT = File.expand_path(File.dirname(__FILE__)) unless defined? DOCROOT

  should "serve files" do
    res = Rack::MockRequest.new(Rack::Lint.new(Rack::File.new(DOCROOT))).
      get("/cgi/test")

    res.should.be.ok
    res.should =~ /ruby/
  end

  should "set Last-Modified header" do
    res = Rack::MockRequest.new(Rack::Lint.new(Rack::File.new(DOCROOT))).
      get("/cgi/test")

    path = File.join(DOCROOT, "/cgi/test")

    res.should.be.ok
    res["Last-Modified"].should.equal File.mtime(path).httpdate
  end

  should "serve files with URL encoded filenames" do
    res = Rack::MockRequest.new(Rack::Lint.new(Rack::File.new(DOCROOT))).
      get("/cgi/%74%65%73%74") # "/cgi/test"

    res.should.be.ok
    res.should =~ /ruby/
  end

  should "not allow directory traversal" do
    res = Rack::MockRequest.new(Rack::Lint.new(Rack::File.new(DOCROOT))).
      get("/cgi/../test")

    res.should.be.forbidden
  end

  should "not allow directory traversal with encoded periods" do
    res = Rack::MockRequest.new(Rack::Lint.new(Rack::File.new(DOCROOT))).
      get("/%2E%2E/README")

    res.should.be.forbidden
  end

  should "404 if it can't find the file" do
    res = Rack::MockRequest.new(Rack::Lint.new(Rack::File.new(DOCROOT))).
      get("/cgi/blubb")

    res.should.be.not_found
  end

  should "detect SystemCallErrors" do
    res = Rack::MockRequest.new(Rack::Lint.new(Rack::File.new(DOCROOT))).
      get("/cgi")

    res.should.be.not_found
  end

  should "return bodies that respond to #to_path" do
    env = Rack::MockRequest.env_for("/cgi/test")
    status, headers, body = Rack::File.new(DOCROOT).call(env)

    path = File.join(DOCROOT, "/cgi/test")

    status.should.equal 200
    body.should.respond_to :to_path
    body.to_path.should.equal path
  end

  should "ignore missing or syntactically invalid byte ranges" do
    Rack::File.byte_ranges({},500).should.equal nil
    Rack::File.byte_ranges({"HTTP_RANGE" => "foobar"},500).should.equal nil
    Rack::File.byte_ranges({"HTTP_RANGE" => "furlongs=123-456"},500).should.equal nil
    Rack::File.byte_ranges({"HTTP_RANGE" => "bytes="},500).should.equal nil
    Rack::File.byte_ranges({"HTTP_RANGE" => "bytes=-"},500).should.equal nil
    Rack::File.byte_ranges({"HTTP_RANGE" => "bytes=123,456"},500).should.equal nil
    # A range of non-positive length is syntactically invalid and ignored:
    Rack::File.byte_ranges({"HTTP_RANGE" => "bytes=456-123"},500).should.equal nil
    Rack::File.byte_ranges({"HTTP_RANGE" => "bytes=456-455"},500).should.equal nil
  end

  should "parse simple byte ranges" do
    Rack::File.byte_ranges({"HTTP_RANGE" => "bytes=123-456"},500).should.equal [(123..456)]
    Rack::File.byte_ranges({"HTTP_RANGE" => "bytes=123-"},500).should.equal [(123..499)]
    Rack::File.byte_ranges({"HTTP_RANGE" => "bytes=-100"},500).should.equal [(400..499)]
    Rack::File.byte_ranges({"HTTP_RANGE" => "bytes=0-0"},500).should.equal [(0..0)]
    Rack::File.byte_ranges({"HTTP_RANGE" => "bytes=499-499"},500).should.equal [(499..499)]
  end

  should "truncate byte ranges" do
    Rack::File.byte_ranges({"HTTP_RANGE" => "bytes=123-999"},500).should.equal [(123..499)]
    Rack::File.byte_ranges({"HTTP_RANGE" => "bytes=600-999"},500).should.equal []
    Rack::File.byte_ranges({"HTTP_RANGE" => "bytes=-999"},500).should.equal [(0..499)]
  end

  should "ignore unsatisfiable byte ranges" do
    Rack::File.byte_ranges({"HTTP_RANGE" => "bytes=500-501"},500).should.equal []
    Rack::File.byte_ranges({"HTTP_RANGE" => "bytes=500-"},500).should.equal []
    Rack::File.byte_ranges({"HTTP_RANGE" => "bytes=999-"},500).should.equal []
    Rack::File.byte_ranges({"HTTP_RANGE" => "bytes=-0"},500).should.equal []
  end

  should "handle byte ranges of empty files" do
    Rack::File.byte_ranges({"HTTP_RANGE" => "bytes=123-456"},0).should.equal []
    Rack::File.byte_ranges({"HTTP_RANGE" => "bytes=0-"},0).should.equal []
    Rack::File.byte_ranges({"HTTP_RANGE" => "bytes=-100"},0).should.equal []
    Rack::File.byte_ranges({"HTTP_RANGE" => "bytes=0-0"},0).should.equal []
    Rack::File.byte_ranges({"HTTP_RANGE" => "bytes=-0"},0).should.equal []
  end

  should "return correct byte range in body" do
    env = Rack::MockRequest.env_for("/cgi/test")
    env["HTTP_RANGE"] = "bytes=22-33"
    res = Rack::MockResponse.new(*Rack::File.new(DOCROOT).call(env))

    res.status.should.equal 206
    res["Content-Length"].should.equal "12"
    res["Content-Range"].should.equal "bytes 22-33/193"
    res.body.should.equal "-*- ruby -*-"
  end

  should "return error for unsatisfiable byte range" do
    env = Rack::MockRequest.env_for("/cgi/test")
    env["HTTP_RANGE"] = "bytes=1234-5678"
    res = Rack::MockResponse.new(*Rack::File.new(DOCROOT).call(env))

    res.status.should.equal 416
    res["Content-Range"].should.equal "bytes */193"
  end

end
