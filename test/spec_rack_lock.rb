require 'test/spec'

require 'rack/mock'
require 'rack/lock'

context "Rack::Lock" do
  class Lock
    attr_reader :synchronized

    def initialize
      @synchronized = false
    end

    def synchronize
      @synchronized = true
      yield
    end
  end

  specify "should call synchronize on lock" do
    lock = Lock.new
    env = Rack::MockRequest.env_for("/")
    app = Rack::Lock.new(lambda { }, lock)
    lock.synchronized.should.equal false
    app.call(env)
    lock.synchronized.should.equal true
  end

  specify "should set multithread flag to false" do
    env = Rack::MockRequest.env_for("/")
    app = Rack::Lock.new(lambda { |env| env['rack.multithread'] })
    app.call(env).should.equal false
  end

  specify "should reset original multithread flag when exiting lock" do
    env = Rack::MockRequest.env_for("/")
    app = Rack::Lock.new(lambda { |env| env })
    app.call(env)['rack.multithread'].should.equal true
  end
end
