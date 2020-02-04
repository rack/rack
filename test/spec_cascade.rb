# frozen_string_literal: true

require_relative 'helper'

describe Rack::Cascade do
  def cascade(*args)
    Rack::Lint.new Rack::Cascade.new(*args)
  end

  docroot = File.expand_path(File.dirname(__FILE__))
  app1 = Rack::Files.new(docroot)

  app2 = Rack::URLMap.new("/crash" => lambda { |env| raise "boom" })

  app3 = Rack::URLMap.new("/foo" => lambda { |env|
                            [200, { "Content-Type" => "text/plain" }, [""]]})

  it "dispatch onward on 404 and 405 by default" do
    cascade = cascade([app1, app2, app3])
    Rack::MockRequest.new(cascade).get("/cgi/test").must_be :ok?
    Rack::MockRequest.new(cascade).get("/foo").must_be :ok?
    Rack::MockRequest.new(cascade).get("/toobad").must_be :not_found?
    Rack::MockRequest.new(cascade).get("/cgi/../..").must_be :client_error?

    # Put is not allowed by Rack::Files so it'll 405.
    Rack::MockRequest.new(cascade).put("/foo").must_be :ok?
  end

  it "dispatch onward on whatever is passed" do
    cascade = cascade([app1, app2, app3], [404, 403])
    Rack::MockRequest.new(cascade).get("/cgi/../bla").must_be :not_found?
  end

  it "include? returns whether app is included" do
    cascade = Rack::Cascade.new([app1, app2])
    cascade.include?(app1).must_equal true
    cascade.include?(app2).must_equal true
    cascade.include?(app3).must_equal false
  end

  it "return 404 if empty" do
    Rack::MockRequest.new(cascade([])).get('/').must_be :not_found?
  end

  it "uses new response object if empty" do
    app = Rack::Cascade.new([])
    res = app.call('/')
    s, h, body = res
    s.must_equal 404
    h['Content-Type'].must_equal 'text/plain'
    body.must_be_empty

    res[0] = 200
    h['Content-Type'] = 'text/html'
    body << "a"

    res = app.call('/')
    s, h, body = res
    s.must_equal 404
    h['Content-Type'].must_equal 'text/plain'
    body.must_be_empty
  end

  it "returns final response if all responses are cascaded" do
   app = Rack::Cascade.new([])
   app << lambda { |env| [405, {}, []] }
   app.call({})[0].must_equal 405
  end

  it "append new app" do
    cascade = Rack::Cascade.new([], [404, 403])
    Rack::MockRequest.new(cascade).get('/').must_be :not_found?
    cascade << app2
    Rack::MockRequest.new(cascade).get('/cgi/test').must_be :not_found?
    Rack::MockRequest.new(cascade).get('/cgi/../bla').must_be :not_found?
    cascade << app1
    Rack::MockRequest.new(cascade).get('/cgi/test').must_be :ok?
    Rack::MockRequest.new(cascade).get('/cgi/../..').must_be :client_error?
    Rack::MockRequest.new(cascade).get('/foo').must_be :not_found?
    cascade << app3
    Rack::MockRequest.new(cascade).get('/foo').must_be :ok?
  end

  it "close the body on cascade" do
    body = StringIO.new
    closer = lambda { |env| [404, {}, body] }
    cascade = Rack::Cascade.new([closer, app3], [404])
    Rack::MockRequest.new(cascade).get("/foo").must_be :ok?
    body.must_be :closed?
  end
end
