require 'thread'
require 'rack/body_proxy'

module Rack
  class Lock
    FLAG = 'rack.multithread'.freeze

    def initialize(app, mutex = Mutex.new)
      @app, @mutex = app, mutex
    end

    def call(env)
      @mutex.lock
      begin
        response = @app.call(env.merge(FLAG => false))
        body = BodyProxy.new(response[2]) { @mutex.unlock }
        response[2] = body
        response
      ensure
        @mutex.unlock unless body
      end
    end
  end
end
