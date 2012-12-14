require 'rack/cascade'
require 'rack/file'
require 'rack/lint'
require 'rack/urlmap'
require 'rack/mock'

describe Rack::Cascade do
  def cascade(*args)
    Rack::Lint.new Rack::Cascade.new(*args)
  end
  
  docroot = File.expand_path(File.dirname(__FILE__))
  app1 = Rack::File.new(docroot)

  app2 = Rack::URLMap.new("/crash" => lambda { |env| raise "boom" })

  app3 = Rack::URLMap.new("/foo" => lambda { |env|
                            [200, { "Content-Type" => "text/plain"}, [""]]})

  should "dispatch onward on 404 and 405 by default" do
    cascade = cascade([app1, app2, app3])
    Rack::MockRequest.new(cascade).get("/cgi/test").should.be.ok
    Rack::MockRequest.new(cascade).get("/foo").should.be.ok
    Rack::MockRequest.new(cascade).get("/toobad").should.be.not_found
    Rack::MockRequest.new(cascade).get("/cgi/../..").should.be.client_error

    # Put is not allowed by Rack::File so it'll 405.
    Rack::MockRequest.new(cascade).put("/foo").should.be.ok
  end

  should "call close on the response's body if the response was dispatch onward and it is not the last in the cascade" do
    called = false
    appa = Rack::URLMap.new("/nope" => lambda { |env|
                                [404, { "Content-Type" => "text/plain"}, Rack::BodyProxy.new([]) { called = true }]})
    cascade = cascade([appa, app1])
    Rack::MockRequest.new(cascade).get("/nope")
    called.should.be.true
  end

  should "not call close if the last response in the cascade was dispatch onward" do
    called = false
    appa = Rack::URLMap.new("/nope" => lambda { |env|
                                [404, { "Content-Type" => "text/plain"}, Rack::BodyProxy.new([]) { called = true }]})
    cascade = cascade([app1, appa])
    Rack::MockRequest.new(cascade).get("/nope", :dontclose => true)
    called.should.be.false
  end

  should "dispatch onward on whatever is passed" do
    cascade = cascade([app1, app2, app3], [404, 403])
    Rack::MockRequest.new(cascade).get("/cgi/../bla").should.be.not_found
  end

  should "return 404 if empty" do
    Rack::MockRequest.new(cascade([])).get('/').should.be.not_found
  end

  should "append new app" do
    cascade = Rack::Cascade.new([], [404, 403])
    Rack::MockRequest.new(cascade).get('/').should.be.not_found
    cascade << app2
    Rack::MockRequest.new(cascade).get('/cgi/test').should.be.not_found
    Rack::MockRequest.new(cascade).get('/cgi/../bla').should.be.not_found
    cascade << app1
    Rack::MockRequest.new(cascade).get('/cgi/test').should.be.ok
    Rack::MockRequest.new(cascade).get('/cgi/../..').should.be.client_error
    Rack::MockRequest.new(cascade).get('/foo').should.be.not_found
    cascade << app3
    Rack::MockRequest.new(cascade).get('/foo').should.be.ok
  end
end
