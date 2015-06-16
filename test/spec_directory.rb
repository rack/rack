require 'minitest/autorun'
require 'rack/directory'
require 'rack/lint'
require 'rack/mock'

describe Rack::Directory do
  DOCROOT = File.expand_path(File.dirname(__FILE__)) unless defined? DOCROOT
  FILE_CATCH = proc{|env| [200, {'Content-Type'=>'text/plain', "Content-Length" => "7"}, ['passed!']] }
  app = Rack::Lint.new(Rack::Directory.new(DOCROOT, FILE_CATCH))

  it "serve directory indices" do
    res = Rack::MockRequest.new(Rack::Lint.new(app)).
      get("/cgi/")

    res.must_be :ok?
    assert_match(res, /<html><head>/)
  end

  it "pass to app if file found" do
    res = Rack::MockRequest.new(Rack::Lint.new(app)).
      get("/cgi/test")

    res.must_be :ok?
    assert_match(res, /passed!/)
  end

  it "serve uri with URL encoded filenames" do
    res = Rack::MockRequest.new(Rack::Lint.new(app)).
      get("/%63%67%69/") # "/cgi/test"

    res.must_be :ok?
    assert_match(res, /<html><head>/)

    res = Rack::MockRequest.new(Rack::Lint.new(app)).
      get("/cgi/%74%65%73%74") # "/cgi/test"

    res.must_be :ok?
    assert_match(res, /passed!/)
  end

  it "not allow directory traversal" do
    res = Rack::MockRequest.new(Rack::Lint.new(app)).
      get("/cgi/../test")

    res.must_be :forbidden?

    res = Rack::MockRequest.new(Rack::Lint.new(app)).
      get("/cgi/%2E%2E/test")

    res.must_be :forbidden?
  end

  it "404 if it can't find the file" do
    res = Rack::MockRequest.new(Rack::Lint.new(app)).
      get("/cgi/blubb")

    res.must_be :not_found?
  end

  it "uri escape path parts" do # #265, properly escape file names
    mr = Rack::MockRequest.new(Rack::Lint.new(app))

    res = mr.get("/cgi/test%2bdirectory")

    res.must_be :ok?
    res.body.must_match(%r[/cgi/test%2Bdirectory/test%2Bfile])

    res = mr.get("/cgi/test%2bdirectory/test%2bfile")
    res.must_be :ok?
  end

  it "correctly escape script name" do
    app2 = Rack::Builder.new do
      map '/script-path' do
        run app
      end
    end

    mr = Rack::MockRequest.new(Rack::Lint.new(app2))

    res = mr.get("/script-path/cgi/test%2bdirectory")

    res.must_be :ok?
    res.body.must_match(%r[/script-path/cgi/test%2Bdirectory/test%2Bfile])

    res = mr.get("/script-path/cgi/test%2bdirectory/test%2bfile")
    res.must_be :ok?
  end
end
