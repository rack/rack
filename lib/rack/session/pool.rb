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
    # Example:
    #   myapp = MyRackApp.new
    #   sessioned = Rack::Session::Pool.new(myapp,
    #     :key => 'rack.session',
    #     :domain => 'foo.com',
    #     :path => '/',
    #     :expire_after => 2592000
    #   )
    #   Rack::Handler::WEBrick.run sessioned

    class Pool < Abstract::ID
      attr_reader :mutex, :pool
      DEFAULT_OPTIONS = Abstract::ID::DEFAULT_OPTIONS.dup

      def initialize(app, options={})
        super
        @pool = Hash.new{|h,k| h[k]={} }
        @mutex = Mutex.new
      end

      private

      def get_session(sid)
        session = @mutex.synchronize do
          sid = generate_sid if sid.nil? or not @pool.key? sid
          @pool[sid]
        end
        [sid, session]
      end

      def set_session(sid, session, options)
        @mutex.synchronize do
          old_session = @pool[sid]
          session = old_session.merge(session)
          @pool[sid] = session
          session.each do |k,v|
            next unless old_session.has_key?(k) and v != old_session[k]
            warn "session value assignment collision at #{k}: #{old_session[k]} <- #{v}"
          end if $DEBUG
        end
        return true
      rescue
        warn "#{session.inspect} has been lost."
        warn $!.inspect
        return false
      end
    end
  end
end
