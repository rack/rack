require 'test/spec'

require 'rack/recursive'
require 'rack/urlmap'
require 'rack/response'
require 'rack/testrequest'

context "Rack::Recursive" do
  setup do

    @app1 = lambda { |env|
      res = Rack::Response.new
      res["X-Path-Info"] = env["PATH_INFO"]
      res["X-Query-String"] = env["QUERY_STRING"]
      res.finish do |res|
        res.write "App1"
      end
    }

    @app2 = lambda { |env|
      Rack::Response.new.finish do |res|
        res.write "App2"
        _, _, body = env['rack.recursive.include'].call(env, "/app1")
        body.each { |b|
          res.write b
        }
      end
    }

    @app3 = lambda { |env|
      raise Rack::ForwardRequest.new("/app1")
    }

    @app4 = lambda { |env|
      raise Rack::ForwardRequest.new("http://example.org/app1/quux?meh")
    }

  end

  specify "should allow for subrequests" do
    app = Rack::Recursive.new(Rack::URLMap.new("/app1" => @app1,
                                               "/app2" => @app2))

    status, _, b = app.call(TestRequest.env("PATH_INFO" => "/app2",
                                            "SCRIPT_NAME" => ""))
    str = ""; b.each { |p| str << p }

    status.should.equal 200
    str.should.equal "App2App1"    
  end

  specify "should raise error on requests not below the app" do
    app = Rack::URLMap.new("/app1" => @app1,
                           "/app" => Rack::Recursive.new(
                              Rack::URLMap.new("/1" => @app1,
                                               "/2" => @app2)))

    lambda {
      status, _, b = app.call(TestRequest.env("PATH_INFO" => "/app/2",
                                              "SCRIPT_NAME" => ""))
      b.each { }
    }.should.raise(ArgumentError).
      message.should =~ /can only include below/
  end

  specify "should support forwarding" do
    app = Rack::Recursive.new(Rack::URLMap.new("/app1" => @app1,
                                               "/app3" => @app3,
                                               "/app4" => @app4))

    status, _, b = app.call(TestRequest.env("PATH_INFO" => "/app3",
                                            "SCRIPT_NAME" => ""))
    str = ""; b.each { |p| str << p }

    status.should.equal 200
    str.should.equal "App1"


    status, h, b = app.call(TestRequest.env("PATH_INFO" => "/app4",
                                            "SCRIPT_NAME" => ""))
    str = ""; b.each { |p| str << p }

    status.should.equal 200
    str.should.equal "App1"
    h["X-Path-Info"].should.equal "/quux"
    h["X-Query-String"].should.equal "meh"
  end
end
