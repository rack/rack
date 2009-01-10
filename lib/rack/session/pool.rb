# AUTHOR: blink <blinketje@gmail.com>; blink#ruby-lang@irc.freenode.net
# THANKS:
#   apeiros, for session id generation, expiry setup, and threadiness
#   sergio, threadiness and bugreps

require 'rack/session/abstract/id'
require 'thread'

module Rack
  module Session
    # Rack::Session::Pool provides simple cookie based session management.
    # Session data is stored in a hash held by @pool.
    # In the context of a multithreaded environment, sessions being
    # committed to the pool is done in a merging manner.
    #
    # The :drop option is available in rack.session.options if you with to
    # explicitly remove the session from the session cache.
    #
    # Example:
    #   myapp = MyRackApp.new
    #   sessioned = Rack::Session::Pool.new(myapp,
    #     :domain => 'foo.com',
    #     :expire_after => 2592000
    #   )
    #   Rack::Handler::WEBrick.run sessioned

    class Pool < Abstract::ID
      attr_reader :mutex, :pool
      DEFAULT_OPTIONS = Abstract::ID::DEFAULT_OPTIONS.merge :drop => false

      def initialize(app, options={})
        super
        @pool = Hash.new
        @mutex = Mutex.new
      end

      def generate_sid
        loop do
          sid = super
          break sid unless @pool.key? sid
        end
      end

      def get_session(sid)
        session = @pool[sid] and return [sid, session]
        @mutex.synchronize do
          session = @pool[sid = generate_sid] = {}
          [sid, session]
        end
      end

      def set_session(session_id, new_session, options)
        @mutex.synchronize do
          session = @pool.delete(session_id) || {}
          break if options[:drop]
          session_id = generate_sid if options[:renew]
          warn "//@#{session_id}: #{(session.keys&new_session.keys)*' '}" if $DEBUG
          session = session.merge(new_session)
          @pool.store(session_id, session)
        end
        return session_id
      rescue
        warn "#{new_session.inspect} has been lost."
        warn $!.inspect
      end
    end
  end
end
