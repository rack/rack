require 'test/spec'

require 'rack/session/pool'
require 'rack/mock'
require 'rack/response'
require 'thread'

context "Rack::Session::Pool" do
  incrementor = lambda do |env|
    env["rack.session"]["counter"] ||= 0
    env["rack.session"]["counter"] += 1
    Rack::Response.new(env["rack.session"].inspect).to_a
  end

  specify "creates a new cookie" do
    pool = Rack::Session::Pool.new(incrementor)
    res = Rack::MockRequest.new(pool).get("/")
    res["Set-Cookie"].should.match("rack.session=")
    res.body.should.equal '{"counter"=>1}'
  end

  specify "determines session from a cookie" do
    pool = Rack::Session::Pool.new(incrementor)
    req = Rack::MockRequest.new(pool)
    res = req.get("/")
    cookie = res["Set-Cookie"]
    req.get("/", "HTTP_COOKIE" => cookie).
      body.should.equal '{"counter"=>2}'
    req.get("/", "HTTP_COOKIE" => cookie).
      body.should.equal '{"counter"=>3}'
  end

  specify "survives broken cookies" do
    pool = Rack::Session::Pool.new(incrementor)
    res = Rack::MockRequest.new(pool).
      get("/", "HTTP_COOKIE" => "rack.session=blarghfasel")
    res.body.should.equal '{"counter"=>1}'
  end

  specify "survives unfound cookies" do
    pool = Rack::Session::Pool.new(incrementor)
    req = Rack::MockRequest.new(pool)
    sid = Array.new(5){rand(16).to_s(16)}*''
    req.get("/", "HTTP_COOKIE" => "rack.session="+sid).
      body.should.equal '{"counter"=>1}'
  end

  # anyone know how to do this better?
  specify "multithread: should merge sessions" do
    pool = Rack::Session::Pool.new(incrementor)
    req = Rack::MockRequest.new(pool)

    res = req.get('/')
    res.body.should.equal '{"counter"=>1}'
    cookie = res["Set-Cookie"]
    sess_id = cookie[/#{pool.key}=([^,;]+)/,1]

    delta_incrementor = lambda do |env|
      # emulate disconjoinment of threading
      env['rack.session'] = env['rack.session'].dup
      Thread.stop
      env['rack.session'][(Time.now.usec*rand).to_i] = true
      incrementor.call(env)
    end
    tses = Rack::Utils::Context.new pool, delta_incrementor
    treq = Rack::MockRequest.new(tses)
    tnum = rand(7).to_i+5
    r = Array.new(tnum) do
      Thread.new(treq) do |run|
        run.get('/', "HTTP_COOKIE" => cookie, 'rack.multithread' => true)
      end
    end.reverse.map{|t| t.run.join.value }
    r.each do |res|
      res['Set-Cookie'].should.equal cookie
      res.body.should.include '"counter"=>2'
    end

    session = pool.pool[sess_id]
    session.size.should.be tnum+1 # counter
    session['counter'].should.be 2 # meeeh
  end
end
