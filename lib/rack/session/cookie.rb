require 'openssl'
require 'rack/request'
require 'rack/response'
require 'rack/session/abstract/id'

module Rack

  module Session

    # Rack::Session::Cookie provides simple cookie based session management.
    # The session is a Ruby Hash stored as base64 encoded marshalled data
    # set to :key (default: rack.session).
    # When the secret key is set, cookie data is checked for data integrity.
    #
    # Example:
    #
    #     use Rack::Session::Cookie, :key => 'rack.session',
    #                                :domain => 'foo.com',
    #                                :path => '/',
    #                                :expire_after => 2592000,
    #                                :secret => 'change_me'
    #
    #     All parameters are optional.

    class Cookie < Abstract::ID
      def initialize(app, options={})
        @secret = options.delete(:secret)
        super
      end

      private

      def load_session(env)
        request = Rack::Request.new(env)
        session_data = request.cookies[@key]

        if @secret && session_data
          session_data, digest = session_data.split("--")
          session_data = nil  unless digest == generate_hmac(session_data)
        end

        begin
          session_data = session_data.unpack("m*").first
          session_data = Marshal.load(session_data)
          env["rack.session"] = session_data
        rescue
          env["rack.session"] = Hash.new
        end

        env["rack.session.options"] = @default_options.dup
      end

      def set_session(env, session_id, session, options)
        session_data = [Marshal.dump(session)].pack("m*")

        if @secret
          session_data = "#{session_data}--#{generate_hmac(session_data)}"
        end

        if session_data.size > (4096 - @key.size)
          env["rack.errors"].puts("Warning! Rack::Session::Cookie data size exceeds 4K.")
          nil
        else
          session_data
        end
      end

      # Overwrite set cookie to bypass content equality and always stream the cookie.

      def set_cookie(env, headers, cookie)
        Utils.set_cookie_header!(headers, @key, cookie)
      end

      def generate_hmac(data)
        OpenSSL::HMAC.hexdigest(OpenSSL::Digest::SHA1.new, @secret, data)
      end

    end
  end
end
