require 'minitest/autorun'
require 'rack/session/file'
require 'rack/lint'
require 'rack/mock'

describe Rack::Session::File do
  incrementor = lambda do |env|
    env["rack.session"]["counter"] ||= 0
    env["rack.session"]["counter"] += 1
    hash = env["rack.session"].dup
    hash.delete("session_id")
    Rack::Response.new(hash.inspect).to_a
  end

  session_id = lambda do |env|
    Rack::Response.new(env["rack.session"].to_hash.inspect).to_a
  end

  session_option = lambda do |opt|
    lambda do |env|
      Rack::Response.new(env["rack.session.options"][opt].inspect).to_a
    end
  end

  nothing = lambda do |env|
    Rack::Response.new("Nothing").to_a
  end

  renewer = lambda do |env|
    env["rack.session.options"][:renew] = true
    Rack::Response.new("Nothing").to_a
  end

  only_session_id = lambda do |env|
    Rack::Response.new(env["rack.session"]["session_id"].to_s).to_a
  end

  bigcookie = lambda do |env|
    env["rack.session"]["cookie"] = "big" * 3000
    Rack::Response.new(env["rack.session"].inspect).to_a
  end

  destroy_session = lambda do |env|
    env["rack.session"].destroy
    Rack::Response.new("Nothing").to_a
  end

  def response_for(options={})
    request_options = options.fetch(:request, {})
    cookie = if options[:cookie].is_a?(Rack::Response)
      options[:cookie]["Set-Cookie"]
    else
      options[:cookie]
    end
    request_options["HTTP_COOKIE"] = cookie || ""

    app_with_cookie = Rack::Session::File.new(*options[:app])
    app_with_cookie = Rack::Lint.new(app_with_cookie)
    Rack::MockRequest.new(app_with_cookie).get("/", request_options)
  end

  before do
    @warnings = warnings = []
    Rack::Session::File.class_eval do
      define_method(:warn) { |m| warnings << m }
    end
  end

  after do
    Rack::Session::File.class_eval { remove_method :warn }
  end

  it "warns if no secret is given" do
    Rack::Session::File.new(incrementor)
    @warnings.first.must_match(/no secret/i)
    @warnings.clear
    Rack::Session::File.new(incrementor, :secret => 'abc')
    @warnings.must_be :empty?
  end

  it "creates a new cookie" do
    response = response_for(:app => incrementor)
    response["Set-Cookie"].must_include "rack.session="
    response.body.must_equal '{"counter"=>1}'
  end

  it "loads from a cookie" do
    response = response_for(:app => incrementor)

    response = response_for(:app => incrementor, :cookie => response)
    response.body.must_equal '{"counter"=>2}'

    response = response_for(:app => incrementor, :cookie => response)
    response.body.must_equal '{"counter"=>3}'
  end

  it "renew session id" do
    response = response_for(:app => incrementor)
    cookie   = response['Set-Cookie']
    response = response_for(:app => only_session_id, :cookie => cookie)
    cookie   = response['Set-Cookie'] if response['Set-Cookie']

    response.body.wont_equal ""
    old_session_id = response.body

    response = response_for(:app => renewer, :cookie => cookie)
    cookie   = response['Set-Cookie'] if response['Set-Cookie']
    response = response_for(:app => only_session_id, :cookie => cookie)

    response.body.wont_equal ""
    response.body.wont_equal old_session_id
  end

  it "destroys session" do
    response = response_for(:app => incrementor)
    response = response_for(:app => only_session_id, :cookie => response)

    response.body.wont_equal ""
    old_session_id = response.body

    response = response_for(:app => destroy_session, :cookie => response)
    response = response_for(:app => only_session_id, :cookie => response)

    response.body.wont_equal ""
    response.body.wont_equal old_session_id
  end

  it "survives broken cookies" do
    response = response_for(
      :app => incrementor,
      :cookie => "rack.session=blarghfasel"
    )
    response.body.must_equal '{"counter"=>1}'

    response = response_for(
      :app => [incrementor, { :secret => "test" }],
      :cookie => "rack.session="
    )
    response.body.must_equal '{"counter"=>1}'
  end

  it "loads from a cookie with integrity hash" do
    app = [incrementor, { :secret => "test" }]

    response = response_for(:app => app)
    response = response_for(:app => app, :cookie => response)
    response.body.must_equal '{"counter"=>2}'

    response = response_for(:app => app, :cookie => response)
    response.body.must_equal '{"counter"=>3}'

    app = [incrementor, { :secret => "other" }]

    response = response_for(:app => app, :cookie => response)
    response.body.must_equal '{"counter"=>1}'
  end

  it "loads from a cookie with accept-only integrity hash for graceful key rotation" do
    response = response_for(:app => [incrementor, { :secret => "test" }])

    app = [incrementor, { :secret => "test2", :old_secret => "test" }]
    response = response_for(:app => app, :cookie => response)
    response.body.must_equal '{"counter"=>2}'

    app = [incrementor, { :secret => "test3", :old_secret => "test2" }]
    response = response_for(:app => app, :cookie => response)
    response.body.must_equal '{"counter"=>3}'
  end

  it "ignores tampered with session cookies" do
    app = [incrementor, { :secret => "test" }]
    response = response_for(:app => app)
    response.body.must_equal '{"counter"=>1}'

    response = response_for(:app => app, :cookie => response)
    response.body.must_equal '{"counter"=>2}'

    _, digest = response["Set-Cookie"].split("--")
    tampered_with_cookie = "hackerman-was-here" + "--" + digest

    response = response_for(:app => app, :cookie => tampered_with_cookie)
    response.body.must_equal '{"counter"=>1}'
  end

  it "supports either of secret or old_secret" do
    app = [incrementor, { :secret => "test" }]
    response = response_for(:app => app)
    response.body.must_equal '{"counter"=>1}'

    response = response_for(:app => app, :cookie => response)
    response.body.must_equal '{"counter"=>2}'

    app = [incrementor, { :old_secret => "test" }]
    response = response_for(:app => app)
    response.body.must_equal '{"counter"=>1}'

    response = response_for(:app => app, :cookie => response)
    response.body.must_equal '{"counter"=>2}'
  end

  it "supports custom digest class" do
    app = [incrementor, { :secret => "test", hmac: OpenSSL::Digest::SHA256 }]

    response = response_for(:app => app)
    response = response_for(:app => app, :cookie => response)
    response.body.must_equal '{"counter"=>2}'

    response = response_for(:app => app, :cookie => response)
    response.body.must_equal '{"counter"=>3}'

    app = [incrementor, { :secret => "other" }]

    response = response_for(:app => app, :cookie => response)
    response.body.must_equal '{"counter"=>1}'
  end

  it "can handle Rack::Lint middleware" do
    response = response_for(:app => incrementor)

    lint = Rack::Lint.new(session_id)
    response = response_for(:app => lint, :cookie => response)
    response.body.wont_be :nil?
  end

  it "can handle middleware that inspects the env" do
    class TestEnvInspector
      def initialize(app)
        @app = app
      end
      def call(env)
        env.inspect
        @app.call(env)
      end
    end

    response = response_for(:app => incrementor)

    inspector = TestEnvInspector.new(session_id)
    response = response_for(:app => inspector, :cookie => response)
    response.body.wont_be :nil?
  end

  it "returns the session id in the session hash" do
    response = response_for(:app => incrementor)
    response.body.must_equal '{"counter"=>1}'

    response = response_for(:app => session_id, :cookie => response)
    response.body.must_match(/"session_id"=>/)
    response.body.must_match(/"counter"=>1/)
  end

  it "does not return a cookie if set to secure but not using ssl" do
    app = [incrementor, { :secure => true }]

    response = response_for(:app => app)
    response["Set-Cookie"].must_be_nil

    response = response_for(:app => app, :request => { "HTTPS" => "on" })
    response["Set-Cookie"].wont_be :nil?
    response["Set-Cookie"].must_match(/secure/)
  end

  it "does not return a cookie if cookie was not read/written" do
    response = response_for(:app => nothing)
    response["Set-Cookie"].must_be_nil
  end

  it "does not return a cookie if cookie was not written (only read)" do
    response = response_for(:app => session_id)
    response["Set-Cookie"].must_be_nil
  end

  it "returns even if not read/written if :expire_after is set" do
    app = [nothing, { :expire_after => 3600 }]
    request = { "rack.session" => { "not" => "empty" }}
    response = response_for(:app => app, :request => request)
    response["Set-Cookie"].wont_be :nil?
  end

  it "returns no cookie if no data was written and no session was created previously, even if :expire_after is set" do
    app = [nothing, { :expire_after => 3600 }]
    response = response_for(:app => app)
    response["Set-Cookie"].must_be_nil
  end

  it "exposes :secret in env['rack.session.option']" do
    response = response_for(:app => [session_option[:secret], { :secret => "foo" }])
    response.body.must_equal '"foo"'
  end

  it "allows passing in a hash with session data from middleware in front" do
    request = { 'rack.session' => { :foo => 'bar' }}
    response = response_for(:app => session_id, :request => request)
    response.body.must_match(/foo/)
  end

  it "allows modifying session data with session data from middleware in front" do
    request = { 'rack.session' => { :foo => 'bar' }}
    response = response_for(:app => incrementor, :request => request)
    response.body.must_match(/counter/)
    response.body.must_match(/foo/)
  end

end
