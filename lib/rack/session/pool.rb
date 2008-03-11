# AUTHOR: blink <blinketje@gmail.com>; blink#ruby-lang@irc.freenode.net

module Rack
  module Session
    # Rack::Session::Pool provides simple cookie based session management.
    # Session data is stored in a hash held by @pool. The corresponding
    # session key sent to the client.
    # The pool is unmonitored and unregulated, which means that over
    # prolonged use the session pool will be very large.
    #
    # Example:
    #
    #     use Rack::Session::Pool, :key => 'rack.session',
    #                              :domain => 'foo.com',
    #                              :path => '/',
    #                              :expire_after => 2592000
    #
    #     All parameters are optional.

    class Pool
      attr_reader :pool, :key
      DEFAULT_OPTIONS = {
          :key =>           'rack.session',
          :path =>          '/',
          :domain =>        nil,
          :expire_after =>  nil
      }

      def initialize(app, options={})
        @app = app
        @default_options = self.class::DEFAULT_OPTIONS.merge(options)
        @key = @default_options[:key]
        @pool = Hash.new
        @default_context = context app
      end

      def call(env)
        @default_context.call(env)
      end

      def context(app)
        Rack::Utils::Context.new self, app do |env|
          load_session env
          response = app.call(env)
          commit_session env, response
          response
        end
      end

      private

      def new_session_id
        while sess_id = Array.new(8){rand(16).to_s(16)}*''
          return sess_id unless @pool[sess_id]
        end
      end

      def load_session(env)
        sess_id = env.fetch('HTTP_COOKIE','')[/#{@key}=([^,;]+)/,1]
        sess_id = new_session_id if sess_id.nil?

        env['rack.session'] = @pool[sess_id] || {}
        env['rack.session.options'] = @default_options.dup
        env['rack.session.options'][nil] = [sess_id, Time.now, self]
      end

      def commit_session(env, response)
        save_session env, response
        set_cookie env, response
      end

      def set_cookie(env, response)
        options = env['rack.session.options']
        sess_id, time, z = options[nil]
        raise "Metadata not available." unless self == z

        expiry = time+options[:expire_after] if options[:expire_after]
        cookie = Utils.escape(@key)+'='+Utils.escape(sess_id)
        cookie<< "; domain=#{options[:domain]}" if options[:domain]
        cookie<< "; path=#{options[:path]}" if options[:path]
        cookie<< "; expires=#{expiry}" if defined? expiry

        case a = (h = response[1])['Set-Cookie']
        when Array then  a << cookie
        when String then h['Set-Cookie'] = [a, cookie]
        when nil then    h['Set-Cookie'] = cookie
        end
      end

      def save_session(env, response)
        sess_id, time, z = env['rack.session.options'][nil]
        raise "Metadata not available." unless self == z
        @pool[sess_id] = env['rack.session']
      end
    end
  end
end
