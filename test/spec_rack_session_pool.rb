require 'test/spec'

require 'rack/session/pool'
require 'rack/mock'
require 'rack/response'

context "Rack::Session::Pool" do
  incrementor = lambda { |env|
    env["rack.session"]["counter"] ||= 0
    env["rack.session"]["counter"] += 1
    Rack::Response.new(env["rack.session"].inspect).to_a
  }

  specify "creates a new cookie" do
    pool = Rack::Session::Pool.new(incrementor)
    res = Rack::MockRequest.new(pool).get("/")
    res["Set-Cookie"].should.match("rack.session=")
    res.body.should.equal '{"counter"=>1}'
  end

  specify "loads from a cookie" do
    pool = Rack::Session::Pool.new(incrementor)
    res = Rack::MockRequest.new(pool).get("/")
    cookie = res["Set-Cookie"]
    res = Rack::MockRequest.new(pool).get("/", "HTTP_COOKIE" => cookie)
    res.body.should.equal '{"counter"=>2}'
    res = Rack::MockRequest.new(pool).get("/", "HTTP_COOKIE" => cookie)
    res.body.should.equal '{"counter"=>3}'
  end

  specify "survives broken cookies" do
    pool = Rack::Session::Pool.new(incrementor)
    res = Rack::MockRequest.new(pool).
      get("/", "HTTP_COOKIE" => "rack.session=blarghfasel")
    res.body.should.equal '{"counter"=>1}'
  end
end
