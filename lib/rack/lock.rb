require 'thread'
require 'rack/body_proxy'

module Rack
  # Rack::Lock locks every request inside a mutex, so that every request
  # will effectively be executed synchronously.
  class Lock
    FLAG = 'rack.multithread'.freeze

    def initialize(app, mutex = Mutex.new)
      @app, @mutex = app, mutex
      @sig = ConditionVariable.new
      @count = 0
    end

    def call(env)
      old, env[FLAG] = env[FLAG], false
      @mutex.lock
      @count += 1
      @sig.wait(@mutex) if @count > 1
      response = @app.call(env)
      body = BodyProxy.new(response[2]) {
        @mutex.synchronize { unlock }
      }
      response[2] = body
      response
    ensure
      unlock unless body
      @mutex.unlock
      env[FLAG] = old
    end

    private

    def unlock
      @count -= 1
      @sig.signal
    end
  end
end
