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
        @default_options = DEFAULT_OPTIONS.merge(options)
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

      def load_session(env)
        sess_id = env.fetch('HTTP_COOKIE','')[/#{@key}=([^,;]+)/,1]
        begin
          sess_id = Array.new(8){rand(16).to_s(16)}*''
        end while @pool.key? sess_id if sess_id.nil? or !@pool.key? sess_id

        session = @pool.fetch sess_id, {}
        session.instance_variable_set '@dat', [sess_id, Time.now]

        @pool.store sess_id, env['rack.session'] = session
        env["rack.session.options"] = @default_options.dup
      end

      def commit_session(env, response)
        session = env['rack.session']
        options = env['rack.session.options']
        sdat    = session.instance_variable_get '@dat'

        cookie = Utils.escape(@key)+'='+Utils.escape(sdat[0])
        cookie<< "; domain=#{options[:domain]}" if options[:domain]
        cookie<< "; path=#{options[:path]}" if options[:path]
        cookie<< "; expires=#{sdat[1]+options[:expires_after]}" if options[:expires_after]

        case a = (h = response[1])['Set-Cookie']
        when Array then  a << cookie
        when String then h['Set-Cookie'] = [a, cookie]
        when nil then    h['Set-Cookie'] = cookie
        end
      end

    end
  end
end
