require 'rack/lint'
require 'rack/lock'
require 'rack/mock'


module Rack
  class Lock
    def would_block
      @count > 0
    end
  end
end

module LockHelpers
  def lock_app(app)
    app = Rack::Lock.new(app)
    return app, Rack::Lint.new(app)
  end
end

describe Rack::Lock do
  extend LockHelpers

  describe 'Proxy' do
    extend LockHelpers

    should 'delegate each' do
      env      = Rack::MockRequest.env_for("/")
      response = Class.new {
        attr_accessor :close_called
        def initialize; @close_called = false; end
        def each; %w{ hi mom }.each { |x| yield x }; end
      }.new

      app = lock_app(lambda { |inner_env| [200, {"Content-Type" => "text/plain"}, response] })[1]
      response = app.call(env)[2]
      list = []
      response.each { |x| list << x }
      list.should.equal %w{ hi mom }
    end

    should 'delegate to_path' do
      env  = Rack::MockRequest.env_for("/")

      res = ['Hello World']
      def res.to_path ; "/tmp/hello.txt" ; end

      app = Rack::Lock.new(lambda { |inner_env| [200, {"Content-Type" => "text/plain"}, res] })
      body = app.call(env)[2]

      body.should.respond_to :to_path
      body.to_path.should.equal "/tmp/hello.txt"
    end

    should 'not delegate to_path if body does not implement it' do
      env  = Rack::MockRequest.env_for("/")

      res = ['Hello World']

      app = lock_app(lambda { |inner_env| [200, {"Content-Type" => "text/plain"}, res] })[1]
      body = app.call(env)[2]

      body.should.not.respond_to :to_path
    end
  end

  should 'call super on close' do
    env      = Rack::MockRequest.env_for("/")
    response = Class.new {
      attr_accessor :close_called
      def initialize; @close_called = false; end
      def close; @close_called = true; end
    }.new

    app = lock_app(lambda { |inner_env| [200, {"Content-Type" => "text/plain"}, response] })[1]
    app.call(env)
    response.close_called.should.equal false
    response.close
    response.close_called.should.equal true
  end

  should "not unlock until body is closed" do
    env      = Rack::MockRequest.env_for("/")
    response = Object.new
    lock, app      = lock_app(lambda { |inner_env| [200, {"Content-Type" => "text/plain"}, response] })
    lock.would_block.should.equal false
    response = app.call(env)[2]
    lock.would_block.should.equal true
    response.close
    lock.would_block.should.equal false
  end

  should "return value from app" do
    env  = Rack::MockRequest.env_for("/")
    body = [200, {"Content-Type" => "text/plain"}, %w{ hi mom }]
    app  = lock_app(lambda { |inner_env| body })[1]

    res = app.call(env)
    res[0].should.equal body[0]
    res[1].should.equal body[1]
    res[2].to_enum.to_a.should.equal ["hi", "mom"]
  end

  should "call synchronize on lock" do
    env = Rack::MockRequest.env_for("/")
    lock, app = lock_app(lambda { |inner_env| [200, {"Content-Type" => "text/plain"}, %w{ a b c }] })
    lock.would_block.should.equal false
    app.call(env)
    lock.would_block.should.equal true
  end

  should "unlock if the app raises" do
    env = Rack::MockRequest.env_for("/")
    lock, app = lock_app(lambda { raise Exception })
    lambda { app.call(env) }.should.raise(Exception)
    lock.would_block.should.equal false
  end

  should "unlock if the app throws" do
    env = Rack::MockRequest.env_for("/")
    lock, app = lock_app(lambda {|_| throw :bacon })
    lambda { app.call(env) }.should.throw(:bacon)
    lock.would_block.should.equal false
  end

  should "set multithread flag to false" do
    app = lock_app(lambda { |env|
      env['rack.multithread'].should.equal false
      [200, {"Content-Type" => "text/plain"}, %w{ a b c }]
    })[1]
    app.call(Rack::MockRequest.env_for("/"))
  end

  should "reset original multithread flag when exiting lock" do
    app = Class.new(Rack::Lock) {
      def call(env)
        env['rack.multithread'].should.equal true
        super
      end
    }.new(lambda { |env| [200, {"Content-Type" => "text/plain"}, %w{ a b c }] })
    Rack::Lint.new(app).call(Rack::MockRequest.env_for("/"))
  end
end
