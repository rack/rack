require 'rack/static'
require 'rack/lint'
require 'rack/mock'

class DummyApp
  def call(env)
    [200, {"Content-Type" => "text/plain"}, ["Hello World"]]
  end
end

describe Rack::Static do
  def static(app, *args)
    Rack::Lint.new Rack::Static.new(app, *args)
  end

  root = File.expand_path(File.dirname(__FILE__))

  OPTIONS = {:urls => ["/cgi"], :root => root}
  STATIC_OPTIONS = {:urls => [""], :root => "#{root}/static", :index => 'index.html'}
  HASH_OPTIONS = {:urls => {"/cgi/sekret" => 'cgi/test'}, :root => root}

  @request = Rack::MockRequest.new(static(DummyApp.new, OPTIONS))
  @static_request = Rack::MockRequest.new(static(DummyApp.new, STATIC_OPTIONS))
  @hash_request = Rack::MockRequest.new(static(DummyApp.new, HASH_OPTIONS))

  it "serves files" do
    res = @request.get("/cgi/test")
    res.should.be.ok
    res.body.should =~ /ruby/
  end

  it "404s if url root is known but it can't find the file" do
    res = @request.get("/cgi/foo")
    res.should.be.not_found
  end

  it "calls down the chain if url root is not known" do
    res = @request.get("/something/else")
    res.should.be.ok
    res.body.should == "Hello World"
  end

  it "calls index file when requesting root in the given folder" do
    res = @static_request.get("/")
    res.should.be.ok
    res.body.should =~ /index!/

    res = @static_request.get("/other/")
    res.should.be.not_found

    res = @static_request.get("/another/")
    res.should.be.ok
    res.body.should =~ /another index!/
  end

  it "doesn't call index file if :index option was omitted" do
    res = @request.get("/")
    res.body.should == "Hello World"
  end

  it "serves hidden files" do
    res = @hash_request.get("/cgi/sekret")
    res.should.be.ok
    res.body.should =~ /ruby/
  end

  it "calls down the chain if the URI is not specified" do
    res = @hash_request.get("/something/else")
    res.should.be.ok
    res.body.should == "Hello World"
  end

  it "supports serving fixed cache-control" do
    opts = OPTIONS.merge(:cache_control => 'public')
    request = Rack::MockRequest.new(static(DummyApp.new, opts))
    res = request.get("/cgi/test")
    res.should.be.ok
    res.headers['Cache-Control'].should == 'public'
  end

  it "supports serving custom http headers" do
    opts = OPTIONS.merge(:headers => {'Cache-Control' => 'public, max-age=42',
      'Access-Control-Allow-Origin' => '*'})
    request = Rack::MockRequest.new(static(DummyApp.new, opts))
    res = request.get("/cgi/test")
    res.should.be.ok
    res.headers['Cache-Control'].should == 'public, max-age=42'
    res.headers['Access-Control-Allow-Origin'].should == '*'
  end

  it "allows headers hash to take priority over fixed cache-control" do
    opts = OPTIONS.merge(:cache_control => 'public, max-age=38',
      :headers => {'Cache-Control' => 'public, max-age=42'})
    request = Rack::MockRequest.new(static(DummyApp.new, opts))
    res = request.get("/cgi/test")
    res.should.be.ok
    res.headers['Cache-Control'].should == 'public, max-age=42'
  end

end
