# frozen_string_literal: true

module Rack
  class Lock
    def initialize(app)
      @app = app
      @mutex = ::Thread::Mutex.new
    end

    def call(env)
      @mutex.synchronize do
        @app.call(env)
      end
    end

    def self.rackup(config, app)
      if config.multithread? || (config.concurrent? && RUBY_VERSION >= '3')
        new(app)
      else
        app
      end
    end
  end
end
