require 'test/spec'

require 'rack/handler/mongrel'
require 'rack/lint'
require 'testrequest'

Thread.abort_on_exception = true
$tcp_defer_accept_opts = nil
$tcp_cork_opts = nil

context "Rack::Handler::Mongrel" do
  include TestRequest::Helpers
  
  setup do
    server = Mongrel::HttpServer.new(@host='0.0.0.0', @port=9201)
    server.register('/test',
                    Rack::Handler::Mongrel.new(Rack::Lint.new(TestRequest.new)))
    @acc = server.run
  end

  specify "should respond" do
    lambda {
      GET("/test")
    }.should.not.raise
  end

  specify "should be a Mongrel" do
    GET("/test")
    status.should.be 200
    response["SERVER_SOFTWARE"].should =~ /Mongrel/
    response["HTTP_VERSION"].should.equal "HTTP/1.1"
    response["SERVER_PROTOCOL"].should.equal "HTTP/1.1"
    response["SERVER_PORT"].should.equal "9201"
    response["SERVER_NAME"].should.equal "0.0.0.0"
  end

  specify "should have rack headers" do
    GET("/test")
    response["rack.version"].should.equal [0,1]
    response["rack.multithread"].should.be true
    response["rack.multiprocess"].should.be false
    response["rack.run_once"].should.be false
  end

  specify "should have CGI headers on GET" do
    GET("/test")
    response["REQUEST_METHOD"].should.equal "GET"
    response["SCRIPT_NAME"].should.equal "/test"
    response["REQUEST_PATH"].should.equal "/test"
    response["PATH_INFO"].should.be.nil
    response["QUERY_STRING"].should.equal ""
    response["test.postdata"].should.equal ""

    GET("/test/foo?quux=1")
    response["REQUEST_METHOD"].should.equal "GET"
    response["SCRIPT_NAME"].should.equal "/test"
    response["REQUEST_PATH"].should.equal "/test/foo"
    response["PATH_INFO"].should.equal "/foo"
    response["QUERY_STRING"].should.equal "quux=1"
  end

  specify "should have CGI headers on POST" do
    POST("/test", {"rack-form-data" => "23"}, {'X-test-header' => '42'})
    status.should.equal 200
    response["REQUEST_METHOD"].should.equal "POST"
    response["SCRIPT_NAME"].should.equal "/test"
    response["REQUEST_PATH"].should.equal "/test"
    response["QUERY_STRING"].should.equal ""
    response["HTTP_X_TEST_HEADER"].should.equal "42"
    response["test.postdata"].should.equal "rack-form-data=23"
  end

  specify "should support HTTP auth" do
    GET("/test", {:user => "ruth", :passwd => "secret"})
    response["HTTP_AUTHORIZATION"].should.equal "Basic cnV0aDpzZWNyZXQ="
  end

  specify "should set status" do
    GET("/test?secret")
    status.should.equal 403
    response["rack.url_scheme"].should.equal "http"
  end

  teardown do
    @acc.raise Mongrel::StopServer
  end
end
