# frozen_string_literal: true

require_relative 'helper'

class NothingMiddleware
  def initialize(app, **)
    @app = app
  end
  def call(env)
    @@env = env
    response = @app.call(env)
    response
  end
  def self.env
    @@env
  end
end

describe Rack::Builder do
  def builder(&block)
    Rack::Lint.new Rack::Builder.new(&block)
  end

  def builder_to_app(&block)
    Rack::Lint.new Rack::Builder.new(&block).to_app
  end

  it "supports mapping" do
    app = builder_to_app do
      map '/' do |outer_env|
        run lambda { |inner_env| [200, { "Content-Type" => "text/plain" }, ['root']] }
      end
      map '/sub' do
        run lambda { |inner_env| [200, { "Content-Type" => "text/plain" }, ['sub']] }
      end
    end
    Rack::MockRequest.new(app).get("/").body.to_s.must_equal 'root'
    Rack::MockRequest.new(app).get("/sub").body.to_s.must_equal 'sub'
  end

  it "supports use when mapping" do
    app = builder_to_app do
      map '/sub' do
        use Rack::ContentLength
        run lambda { |inner_env| [200, { "Content-Type" => "text/plain" }, ['sub']] }
      end
      use Rack::ContentLength
      run lambda { |inner_env| [200, { "Content-Type" => "text/plain" }, ['root']] }
    end
    Rack::MockRequest.new(app).get("/").headers['Content-Length'].must_equal '4'
    Rack::MockRequest.new(app).get("/sub").headers['Content-Length'].must_equal '3'
  end

  it "doesn't dupe env even when mapping" do
    app = builder_to_app do
      use NothingMiddleware, noop: :noop
      map '/' do |outer_env|
        run lambda { |inner_env|
          inner_env['new_key'] = 'new_value'
          [200, { "Content-Type" => "text/plain" }, ['root']]
        }
      end
    end
    Rack::MockRequest.new(app).get("/").body.to_s.must_equal 'root'
    NothingMiddleware.env['new_key'].must_equal 'new_value'
  end

  it "dupe #to_app when mapping so Rack::Reloader can reload the application on each request" do
    app = builder do
      map '/' do |outer_env|
        run lambda { |env|  [200, { "Content-Type" => "text/plain" }, [object_id.to_s]] }
      end
    end

    builder_app1_id = Rack::MockRequest.new(app).get("/").body.to_s
    builder_app2_id = Rack::MockRequest.new(app).get("/").body.to_s

    builder_app2_id.wont_equal builder_app1_id
  end

  it "chains apps by default" do
    app = builder_to_app do
      use Rack::ShowExceptions
      run lambda { |env| raise "bzzzt" }
    end

    Rack::MockRequest.new(app).get("/").must_be :server_error?
    Rack::MockRequest.new(app).get("/").must_be :server_error?
    Rack::MockRequest.new(app).get("/").must_be :server_error?
  end

  it "has implicit #to_app" do
    app = builder do
      use Rack::ShowExceptions
      run lambda { |env| raise "bzzzt" }
    end

    Rack::MockRequest.new(app).get("/").must_be :server_error?
    Rack::MockRequest.new(app).get("/").must_be :server_error?
    Rack::MockRequest.new(app).get("/").must_be :server_error?
  end

  it "supports blocks on use" do
    app = builder do
      use Rack::ShowExceptions
      use Rack::Auth::Basic do |username, password|
        'secret' == password
      end

      run lambda { |env| [200, { "Content-Type" => "text/plain" }, ['Hi Boss']] }
    end

    response = Rack::MockRequest.new(app).get("/")
    response.must_be :client_error?
    response.status.must_equal 401

    # with auth...
    response = Rack::MockRequest.new(app).get("/",
        'HTTP_AUTHORIZATION' => 'Basic ' + ["joe:secret"].pack("m*"))
    response.status.must_equal 200
    response.body.to_s.must_equal 'Hi Boss'
  end

  it "has explicit #to_app" do
    app = builder do
      use Rack::ShowExceptions
      run lambda { |env| raise "bzzzt" }
    end

    Rack::MockRequest.new(app).get("/").must_be :server_error?
    Rack::MockRequest.new(app).get("/").must_be :server_error?
    Rack::MockRequest.new(app).get("/").must_be :server_error?
  end

  it "can mix map and run for endpoints" do
    app = builder do
      map '/sub' do
        run lambda { |inner_env| [200, { "Content-Type" => "text/plain" }, ['sub']] }
      end
      run lambda { |inner_env| [200, { "Content-Type" => "text/plain" }, ['root']] }
    end

    Rack::MockRequest.new(app).get("/").body.to_s.must_equal 'root'
    Rack::MockRequest.new(app).get("/sub").body.to_s.must_equal 'sub'
  end

  it "accepts middleware-only map blocks" do
    app = builder do
      map('/foo') { use Rack::ShowExceptions }
      run lambda { |env| raise "bzzzt" }
    end

    proc { Rack::MockRequest.new(app).get("/") }.must_raise(RuntimeError)
    Rack::MockRequest.new(app).get("/foo").must_be :server_error?
  end

  it "yields the generated app to a block for warmup" do
    warmed_up_app = nil

    app = Rack::Builder.new do
      warmup { |a| warmed_up_app = a }
      run lambda { |env| [200, {}, []] }
    end.to_app

    warmed_up_app.must_equal app
  end

  it "initialize apps once" do
    app = builder do
      class AppClass
        def initialize
          @called = 0
        end
        def call(env)
          raise "bzzzt"  if @called > 0
        @called += 1
          [200, { 'Content-Type' => 'text/plain' }, ['OK']]
        end
      end

      use Rack::ShowExceptions
      run AppClass.new
    end

    Rack::MockRequest.new(app).get("/").status.must_equal 200
    Rack::MockRequest.new(app).get("/").must_be :server_error?
  end

  it "allows use after run" do
    app = builder do
      run lambda { |env| raise "bzzzt" }
      use Rack::ShowExceptions
    end

    Rack::MockRequest.new(app).get("/").must_be :server_error?
    Rack::MockRequest.new(app).get("/").must_be :server_error?
    Rack::MockRequest.new(app).get("/").must_be :server_error?
  end

  it "supports #freeze_app for freezing app and middleware" do
    app = builder do
      freeze_app
      use Rack::ShowExceptions
      use(Class.new do
        def initialize(app) @app = app end
        def call(env) @a = 1 if env['PATH_INFO'] == '/a'; @app.call(env) end
      end)
      o = Object.new
      def o.call(env)
        @a = 1 if env['PATH_INFO'] == '/b';
        [200, {}, []]
      end
      run o
    end

    Rack::MockRequest.new(app).get("/a").must_be :server_error?
    Rack::MockRequest.new(app).get("/b").must_be :server_error?
    Rack::MockRequest.new(app).get("/c").status.must_equal 200
  end

  it 'complains about a missing run' do
    proc do
      Rack::Lint.new Rack::Builder.app { use Rack::ShowExceptions }
    end.must_raise(RuntimeError)
  end

  describe "load_file" do
    def config_file(name)
      File.join(File.dirname(__FILE__), 'builder', name)
    end

    it "removes __END__ before evaluating app" do
      app, _ = Rack::Builder.load_file config_file('end.ru')
      Rack::MockRequest.new(app).get("/").body.to_s.must_equal 'OK'
    end

    it "supports multi-line comments" do
      app = Rack::Builder.load_file(config_file('comment.ru'))
      app.must_be_kind_of(Proc)
    end

    it "sets __LINE__ correctly" do
      app, _ = Rack::Builder.load_file config_file('line.ru')
      Rack::MockRequest.new(app).get("/").body.to_s.must_equal '3'
    end

    it "strips leading unicode byte order mark when present" do
      enc = Encoding.default_external
      begin
        Encoding.default_external = 'UTF-8'
        app, _ = Rack::Builder.load_file config_file('bom.ru')
        Rack::MockRequest.new(app).get("/").body.to_s.must_equal 'OK'
      ensure
        Encoding.default_external = enc
      end
    end

    it "respects the frozen_string_literal magic comment" do
      app, _ = Rack::Builder.load_file(config_file('frozen.ru'))
      response = Rack::MockRequest.new(app).get('/')
      response.body.must_equal 'frozen'
      body = response.instance_variable_get(:@body)
      body.must_equal(['frozen'])
      body[0].frozen?.must_equal true
    end
  end

  describe 'new_from_string' do
    it "builds a rack app from string" do
      app, = Rack::Builder.new_from_string "run lambda{|env| [200, {'Content-Type' => 'text/plane'}, ['OK']] }"
      Rack::MockRequest.new(app).get("/").body.to_s.must_equal 'OK'
    end
  end
end
