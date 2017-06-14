require 'thread'
require 'rack/body_proxy'

module Rack
  # Rack::Lock locks every request inside a mutex, so that every request
  # will effectively be executed synchronously.
  class Lock
    FLAG = 'rack.multithread'.freeze

    def initialize(app, mutex = Mutex.new)
      @app, @mutex = app, mutex
    end

    def call(env)
      @mutex.lock
      begin
        response = @app.call(env.merge(FLAG => false))
        returned = response << BodyProxy.new(response.pop) { @mutex.unlock }
      ensure
        @mutex.unlock unless returned
      end
    end
  end
end
