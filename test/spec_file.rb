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
    req = Rack::MockRequest.new(Rack::Lint.new(Rack::File.new(DOCROOT)))
    res = req.get("/cgi/../test")
    res.should.be.forbidden

    res = req.get("../test")
    res.should.be.forbidden

    res = req.get("..")
    res.should.be.forbidden

    res = req.get("test/..")
    res.should.be.forbidden
  end

  should "allow files with .. in their name" do
    req = Rack::MockRequest.new(Rack::Lint.new(Rack::File.new(DOCROOT)))
    res = req.get("/cgi/..test")
    res.should.be.not_found

    res = req.get("/cgi/test..")
    res.should.be.not_found

    res = req.get("/cgi../test..")
    res.should.be.not_found
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
    status, _, body = Rack::File.new(DOCROOT).call(env)

    path = File.join(DOCROOT, "/cgi/test")

    status.should.equal 200
    body.should.respond_to :to_path
    body.to_path.should.equal path
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

  should "support cache control options" do
    env = Rack::MockRequest.env_for("/cgi/test")
    status, heads, _ = Rack::File.new(DOCROOT, 'public, max-age=38').call(env)

    path = File.join(DOCROOT, "/cgi/test")

    status.should.equal 200
    heads['Cache-Control'].should.equal 'public, max-age=38'
  end

end
