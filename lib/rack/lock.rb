# frozen_string_literal: true

require 'logger'

module Rack
  # Sets up rack.logger to write to rack.errors stream
  class Lock
    class Wrapper
      def initialize(app)
        @app = app
        @mutex = ::Thread::Mutex.new
      end

      def call(env)
        @mutex.synchronize do
          @app.call(env)
        end
      end
    end

    def self.rackup(builder)
      if builder.multithread?
        builder.use(Wrapper)
      end
    end
  end
end
