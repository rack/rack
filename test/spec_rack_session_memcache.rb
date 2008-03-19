require 'test/spec'

require 'rack/session/memcache'
require 'rack/mock'
require 'rack/response'
require 'thread'

context "Rack::Session::Memcache" do
  incrementor = lambda { |env|
    env["rack.session"]["counter"] ||= 0
    env["rack.session"]["counter"] += 1
    Rack::Response.new(env["rack.session"].inspect).to_a
  }

  specify "creates a new cookie" do
    cache = Rack::Session::Memcache.new(incrementor)
    res = Rack::MockRequest.new(cache).get("/")
    res["Set-Cookie"].should.match("rack.session=")
    res.body.should.equal '{"counter"=>1}'
  end

  specify "determines session from a cookie" do
    cache = Rack::Session::Memcache.new(incrementor)
    res = Rack::MockRequest.new(cache).get("/")
    cookie = res["Set-Cookie"]
    res = Rack::MockRequest.new(cache).get("/", "HTTP_COOKIE" => cookie)
    res.body.should.equal '{"counter"=>2}'
    res = Rack::MockRequest.new(cache).get("/", "HTTP_COOKIE" => cookie)
    res.body.should.equal '{"counter"=>3}'
  end

  specify "survives broken cookies" do
    cache = Rack::Session::Memcache.new(incrementor)
    res = Rack::MockRequest.new(cache).
      get("/", "HTTP_COOKIE" => "rack.session=blarghfasel")
    res.body.should.equal '{"counter"=>1}'
  end

  specify "maintains freshness" do
    cache = Rack::Session::Memcache.new(incrementor, :expire_after => 3)
    res = Rack::MockRequest.new(cache).get('/')
    res.body.should.include '"counter"=>1'
    cookie = res["Set-Cookie"]
    res = Rack::MockRequest.new(cache).get('/', "HTTP_COOKIE" => cookie)
    res["Set-Cookie"].should.equal cookie
    res.body.should.include '"counter"=>2'
    sleep 4
    res = Rack::MockRequest.new(cache).get('/', "HTTP_COOKIE" => cookie)
    res["Set-Cookie"].should.not.equal cookie
    res.body.should.include '"counter"=>1'
  end

  specify "multithread: should merge sessions" do
    delta_incrementor = lambda do |env|
      env['rack.session'] = env['rack.session'].dup
      sleep 1
      env['rack.session'][(Time.now.usec*rand).to_i] = true
      incrementor.call(env)
    end
    cache = Rack::Session::Memcache.new(incrementor)
    res = Rack::MockRequest.new(cache).get('/')
    res.body.should.equal '{"counter"=>1}'
    cookie = res["Set-Cookie"]
    sess_id = cookie[/#{cache.key}=([^,;]+)/,1]

    cache = cache.context(delta_incrementor)
    r = Array.new(rand(7).to_i+2).
      map! do
        Thread.new do
          Rack::MockRequest.new(cache).get('/', "HTTP_COOKIE" => cookie, 'rack.multithread' => true)
        end
      end.
      reverse!.
      map!{|t| t.join.value }
    session = cache.for.pool[sess_id] # for is needed by Utils::Context
    session.size.should.be r.size+1 # counter
    session['counter'].should.be 2 # meeeh
    r.each do |res|
      res['Set-Cookie'].should.equal cookie
      res.body.should.include '"counter"=>2'
    end
  end
end
