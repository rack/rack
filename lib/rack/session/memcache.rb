# AUTHOR: blink <blinketje@gmail.com>; blink#ruby-lang@irc.freenode.net

require 'rack/session/abstract/id'
require 'memcache'

module Rack
  module Session
    # Rack::Session::Memcache provides simple cookie based session management.
    # Session data is stored in memcached. The corresponding session key is
    # maintained in the cookie.
    # You may treat Session::Memcache as you would Session::Pool with the
    # following caveats.
    #
    # * Setting :expire_after to 0 would note to the Memcache server to hang
    #   onto the session data until it would drop it according to it's own
    #   specifications. However, the cookie sent to the client would expire
    #   immediately.
    #
    # Note that memcache does drop data before it may be listed to expire. For
    # a full description of behaviour, please see memcache's documentation.

    class Memcache < Abstract::ID

      def initialize(app, options={})
        super app, {
          :namespace => 'rack:session',
          :memcache_server => 'localhost:11211'
        }.merge(options)

        @mutex = Mutex.new
        @pool = MemCache.
          new @default_options[:memcache_server], @default_options
        raise 'No memcache servers' unless @pool.servers.any?{|s|s.alive?}
      end

      def get_session(sid)
        session = sid && @pool.get(sid)
        unless session and session.is_a?(Hash)
          session = {}
          lc = 0
          @mutex.synchronize do
            begin
              raise RuntimeError, 'Unique id finding looping excessively' if (lc+=1) > 1000
              sid = generate_sid
              ret = @pool.add(sid, session)
            end until /^STORED/ =~ ret
          end
        end
        class << session
          def __del_key key; (@deleted||={})[key] = self[key]; end
          def delete k; __del_key k; super; end
          def clear; keys.each{|k| __del_key k }; super; end
        end
        [sid, session]
      rescue MemCache::MemCacheError, Errno::ECONNREFUSED # MemCache server cannot be contacted
        warn "#{self} is unable to find server."
        warn $!.inspect
        return [ nil, {} ]
      end

      def set_session(sid, session, options)
        expiry = options[:expire_after] || 0
        @mutex.synchronize do
          old_session = @pool.get(sid)
          unless old_session.is_a?(Hash)
            warn 'Session not properly initialized.'
            old_session = {}
          end
          del = session.instance_variable_get '@deleted'
          if del and not del.empty?
            del.each{|k| old_session.delete(k) }
          end
          @pool.set sid, old_session.merge(session), expiry
        end
        return true
      rescue MemCache::MemCacheError, Errno::ECONNREFUSED # MemCache server cannot be contacted
        warn "#{self} is unable to find server."
        warn $!.inspect
        return false
      end
    end
  end
end
