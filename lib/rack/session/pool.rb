# AUTHOR: blink <blinketje@gmail.com>; blink#ruby-lang@irc.freenode.net
# THANKS:
#   apeiros, for session id generation, expiry setup, and threadiness
#   sergio, threadiness and bugreps

module Rack
  module Session
    # Rack::Session::Pool provides simple cookie based session management.
    # Session data is stored in a hash held by @pool. The corresponding
    # session key sent to the client.
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
    #
    # All parameters are optional.
    # * :key determines the name of the cookie, by default it is
    #   'rack.session'
    # * :domain and :path set the related cookie values, by default
    #   domain is nil, and the path is '/'.
    # * :expire_after is the number of seconds in which the session
    #   cookie will expire. By default it is set not to provide any
    #   expiry time.

    class Pool
      attr_reader :mutex, :pool, :key
      DEFAULT_OPTIONS = {
          :key =>           'rack.session',
          :path =>          '/',
          :domain =>        nil,
          :expire_after =>  nil
      }

      def initialize(app, options={})
        @default_options = self.class::DEFAULT_OPTIONS.merge(options)
        @key = @default_options[:key]
        @pool = Hash.new
        @mutex = Mutex.new
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

      def get_session(env, sid)
        session = @mutex.synchronize do
          unless @pool.has_key?(sid)
            begin
              sid = "%08x" % rand(0xffffffff)
            end while @pool.has_key?(sid)
          end
          @pool[sid] ||= {}
        end
        [sid, session]
      end

      def set_session(env, sid)
        @mutex.synchronize do
          old_session = @pool[sid]
          session = @pool[sid] = old_session.merge(env['rack.session'])
          session.each{|k,v|
            warn "session collision at #{k}: #{old_session[k]} <- #{v}" if v != old_session[k]
          }
        end
      end

      def load_session(env)
        sess_id = env.fetch('HTTP_COOKIE','')[/#{@key}=([^,;]+)/,1]
        sess_id, env['rack.session'] = get_session(env, sess_id)
        env['rack.session.options'] = {
          :id => sess_id,
          :at => Time.now,
          :by => self
        }.merge(@default_options)
      end

      def commit_session(env, response)
        options = env['rack.session.options']
        sess_id, time, z = options.values_at(:id, :at, :by)
        raise "Metadata not available." unless self == z
        set_session(env, sess_id)

        expiry = options[:expire_after] && time+options[:expire_after]
        cookie = Utils.escape(@key)+'='+Utils.escape(sess_id)
        cookie<< "; domain=#{options[:domain]}" if options[:domain]
        cookie<< "; path=#{options[:path]}" if options[:path]
        cookie<< "; expires=#{expiry}" if expiry

        case a = (h = response[1])['Set-Cookie']
        when Array then  a << cookie
        when String then h['Set-Cookie'] = [a, cookie]
        when nil then    h['Set-Cookie'] = cookie
        end
      end
    end
  end
end
