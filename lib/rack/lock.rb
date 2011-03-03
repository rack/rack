require 'thread'
require 'rack/middleware'

module Rack
  class Lock < Rack::Middleware
    class Proxy < Struct.new(:target, :mutex) # :nodoc:
      def each
        target.each { |x| yield x }
      end

      def close
        target.close if target.respond_to?(:close)
      ensure
        mutex.unlock
      end

      def to_path
        target.to_path
      end

      def respond_to?(sym)
        sym.to_sym == :close || target.respond_to?(sym)
      end
    end

    FLAG = 'rack.multithread'.freeze

    def initialize(app, mutex = Mutex.new)
      super(app)
      @mutex = mutex
    end

    def call(env)
      old, env[FLAG] = env[FLAG], false
      @mutex.lock
      response = super
      response[2] = Proxy.new(response[2], @mutex)
      response
    rescue Exception
      @mutex.unlock
      raise
    ensure
      env[FLAG] = old
    end
  end
end
