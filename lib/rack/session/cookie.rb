require 'openssl'
require 'zlib'
require 'rack/request'
require 'rack/response'
require 'rack/session/abstract/id'
require 'json'

module Rack

  module Session

    # Rack::Session::Cookie provides simple cookie based session management.
    # By default, the session is a Ruby Hash stored as base64 encoded marshalled
    # data set to :key (default: rack.session).  The object that encodes the
    # session data is configurable and must respond to +encode+ and +decode+.
    # Both methods must take a string and return a string.
    #
    # When the secret key is set, cookie data is checked for data integrity.
    # The old secret key is also accepted and allows graceful secret rotation.
    #
    # Example:
    #
    #     use Rack::Session::Cookie, :key => 'rack.session',
    #                                :domain => 'foo.com',
    #                                :path => '/',
    #                                :expire_after => 2592000,
    #                                :secret => 'change_me',
    #                                :old_secret => 'also_change_me'
    #
    #     All parameters are optional.
    #
    # Example of a cookie with no encoding:
    #
    #   Rack::Session::Cookie.new(application, {
    #     :coder => Rack::Coders::Identity.new
    #   })
    #
    # Example of a cookie with custom encoding:
    #
    #   Rack::Session::Cookie.new(application, {
    #     :coder => Class.new {
    #       def encode(str); str.reverse; end
    #       def decode(str); str.reverse; end
    #     }.new
    #   })
    #
    class Cookie < Abstract::Persisted
      # This class is deprecated, use Rack::Coders instead.
      class Base64
        def self.new
          deprecation_warning
          Coders::Rescue.new(Coders::Base64.new(strict: false))
        end

        def self.deprecation_warning
          return unless $VERBOSE
          warn "#{self} is deprecated, use Rack::Coders} instead"
        end

        # Encode session cookies as Marshaled Base64 data
        class Marshal < Base64
          def self.new
            deprecation_warning
            Coders::Rescue.new(Coders::Base64.new(Coders::Marshal.new, strict: false))
          end
        end

        # Encode session cookies as JSON Base64 data
        class JSON < Base64
          def self.new
            deprecation_warning
            Coders::Rescue.new(Coders::Base64.new(Coders::JSON.new, strict: false))
          end
        end

        class ZipJSON < Base64
          def self.new
            deprecation_warning
            Coders::Rescue.new(Coders::Base64.new(Coders::Zip.new(Coders::JSON.new), strict: false))
          end
        end
      end

      # Use no encoding for session cookies
      Identity = Coders::Identity

      attr_reader :coder

      def initialize(app, options={})
        @secrets = options.values_at(:secret, :old_secret).compact
        @hmac = options.fetch(:hmac, OpenSSL::Digest::SHA1)

        warn <<-MSG unless secure?(options)
        SECURITY WARNING: No secret option provided to Rack::Session::Cookie.
        This poses a security threat. It is strongly recommended that you
        provide a secret to prevent exploits that may be possible from crafted
        cookies. This will not be supported in future versions of Rack, and
        future versions will even invalidate your existing user cookies.

        Called from: #{caller[0]}.
        MSG
        @coder  = options[:coder] ||= Coders::Rescue.new(Coders::Base64.new(Coders::Marshal.new))
        super(app, options.merge!(:cookie_only => true))
      end

      private

      def find_session(req, sid)
        data = unpacked_cookie_data(req)
        data = persistent_session_id!(data)
        [data["session_id"], data]
      end

      def extract_session_id(request)
        unpacked_cookie_data(request)["session_id"]
      end

      def unpacked_cookie_data(request)
        request.fetch_header(RACK_SESSION_UNPACKED_COOKIE_DATA) do |k|
          session_data = request.cookies[@key]

          if @secrets.size > 0 && session_data
            digest, session_data = session_data.reverse.split("--", 2)
            digest.reverse! if digest
            session_data.reverse! if session_data
            session_data = nil unless digest_match?(session_data, digest)
          end

          request.set_header(k, coder.decode(session_data) || {})
        end
      end

      def persistent_session_id!(data, sid=nil)
        data ||= {}
        data["session_id"] ||= sid || generate_sid
        data
      end

      def write_session(req, session_id, session, options)
        session = session.merge("session_id" => session_id)
        session_data = coder.encode(session)

        if @secrets.first
          session_data << "--#{generate_hmac(session_data, @secrets.first)}"
        end

        if session_data.size > (4096 - @key.size)
          req.get_header(RACK_ERRORS).puts("Warning! Rack::Session::Cookie data size exceeds 4K.")
          nil
        else
          session_data
        end
      end

      def delete_session(req, session_id, options)
        # Nothing to do here, data is in the client
        generate_sid unless options[:drop]
      end

      def digest_match?(data, digest)
        return unless data && digest
        @secrets.any? do |secret|
          Rack::Utils.secure_compare(digest, generate_hmac(data, secret))
        end
      end

      def generate_hmac(data, secret)
        OpenSSL::HMAC.hexdigest(@hmac.new, secret, data)
      end

      def secure?(options)
        @secrets.size >= 1 ||
        (options[:coder] && options[:let_coder_handle_secure_encoding])
      end

    end
  end
end
