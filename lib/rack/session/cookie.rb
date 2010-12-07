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
        super(app, options.merge!(:cookie_only => true))
      end

      private

      def load_session(env)
        data = unpacked_cookie_data(env)
        data = persistent_session_id!(data)
        [data["session_id"], data]
      end

      def extract_session_id(env)
        unpacked_cookie_data(env)["session_id"]
      end

      def unpacked_cookie_data(env)
        env[RACK_VARIABLE::SESSION_UNPACKED_COOKIE_DATA] ||= begin
          request = Rack::Request.new(env)
          session_data = request.cookies[@key]

          if @secret && session_data
            session_data, digest = session_data.split("--")
            session_data = nil  unless digest == generate_hmac(session_data)
          end

          data = Marshal.load(session_data.unpack("m*").first) rescue nil
          data || {}
        end
      end

      def persistent_session_id!(data, sid=nil)
        data ||= {}
        data["session_id"] ||= sid || generate_sid
        data
      end

      # Overwrite set cookie to bypass content equality and always stream the cookie.

      def set_cookie(env, headers, cookie)
        Utils.set_cookie_header!(headers, @key, cookie)
      end

      def set_session(env, session_id, session, options)
        session = persistent_session_id!(session, session_id)
        session_data = [Marshal.dump(session)].pack("m*")

        if @secret
          session_data = "#{session_data}--#{generate_hmac(session_data)}"
        end

        if session_data.size > (4096 - @key.size)
          env[RACK_VARIABLE::ERRORS].puts("Warning! Rack::Session::Cookie data size exceeds 4K.")
          nil
        else
          session_data
        end
      end

      def destroy_session(env, session_id, options)
        # Nothing to do here, data is in the client
        generate_sid unless options[:drop]
      end

      def generate_hmac(data)
        OpenSSL::HMAC.hexdigest(OpenSSL::Digest::SHA1.new, @secret, data)
      end

    end
  end
end
