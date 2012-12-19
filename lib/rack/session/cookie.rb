require 'openssl'
require 'rack/request'
require 'rack/response'
require 'rack/session/abstract/id'

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
    # Optional encryption of the session cookie is supported. This can be
    # done either with a password-based key, or with a key which you
    # generate using something like:
    #
    #     SecureRandom.random_bytes(key_size_in_bytes_here)
    #
    # For using a password-based key, specify the following options:
    #
    #     :cipher     => 'aes-256-cbc', # The cipher algorithm to use
    #     :salt       => 'salthere',    # Salt to use for key generation
    #     :rounds     => 2000,          # Number of iterations for key generation
    #     :crypto_key => 'yoursecret',  # A password from which to generate the key
    #
    # :crypto_key and :salt must be specified in order to enable encryption.
    # All other options have defaults available.
    #
    # Example:
    #
    #     use Rack::Session::Cookie, :key        => 'rack.session',
    #                                :domain     => 'foo.com',
    #                                :path       => '/',
    #                                :salt       => 'salthere',
    #                                :crypto_key => 'my_secret'
    #
    # For using a pre-generated key, specify the following options:
    #
    #     :cipher     => 'aes-256-cbc', # The cipher algorithm to use
    #     :crypto_key => your_key_here, # Your pre-generated key
    #
    # Example:
    #
    #     use Rack::Session::Cookie, :key        => 'rack.session',
    #                                :domain     => 'foo.com',
    #                                :path       => '/',
    #                                :crypto_key => your_key
    #
    # Note: If you specify a custom coder, and :crypto_key, then your coder will
    # be automatically wrapped to deal with encryption.
    #
    # Example of a cookie with no encoding:
    #
    #   Rack::Session::Cookie.new(application, {
    #     :coder => Rack::Session::Cookie::Identity.new
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

    class Cookie < Abstract::ID
      # Encode session cookies as Base64
      class Base64
        def encode(str)
          [str].pack('m')
        end

        def decode(str)
          str.unpack('m').first
        end

        # Encode session cookies as Marshaled Base64 data
        class Marshal < Base64
          def encode(str)
            super(::Marshal.dump(str))
          end

          def decode(str)
            return unless str
            ::Marshal.load(super(str)) rescue nil
          end
        end
      end

      # Encrypted cookie
      class Encrypted
        attr_accessor :coder

        def initialize(coder=nil,options={})
          @coder   = coder                 || Base64::Marshal.new
          @cipher  = options[:cipher]      || 'aes-256-cbc'
          @salt    = options[:salt]        || nil
          @rounds  = options[:rounds].to_i || 2000
          @key     = options[:crypto_key]  || nil
          @crypto  = @key.nil? ? false : true
        end

        def encode(str)
          return [cipher(:encrypt,@coder.encode(str))].pack('m')
        end

        def decode(str)
          return unless str
          return @coder.decode(cipher(:decrypt,str.unpack('m').first))
        end

        def cipher(mode,str)
            return str unless @crypto && !str.nil?
            begin
              cipher = OpenSSL::Cipher::Cipher.new(@cipher)
              cipher.send(mode)
            rescue
              @crypto = false
              return str
            end

            cipher.key = @salt.nil? ? @key : OpenSSL::PKCS5.pbkdf2_hmac_sha1(@key,@salt,@rounds,cipher.key_len)
            iv         = cipher.random_iv
            xstr       = str

            if mode == :decrypt
              # Extract the IV
              iv_len    = iv.length
              str_b,iv  = Array[str[0...iv_len<<1].unpack('C*')].transpose.partition.with_index { |x,i| (i&1).zero? }
              iv.flatten! ; str_b.flatten!

              # Set the IV and buffer
              iv   = iv.pack('C*')
              xstr = str_b.pack('C*') + str[iv_len<<1...str.length]
            end

            # Otherwise, use the random IV
            cipher.iv = iv

            # Get the result
            result = nil
            begin
              result = cipher.update(xstr) + cipher.final
              result = result.bytes.to_a.zip(iv.bytes.to_a).flatten.compact.pack('C*') if mode == :encrypt
            rescue OpenSSL::Cipher::CipherError
              @crypto = false
              return str
            end

            return result
        end
      end

      # Use no encoding for session cookies
      class Identity
        def encode(str); str; end
        def decode(str); str; end
      end

      # Reverse string encoding. (trollface)
      class Reverse
        def encode(str); str.reverse; end
        def decode(str); str.reverse; end
      end

      attr_reader :coder

      def initialize(app, options={})
        @secrets = options.values_at(:secret, :old_secret).compact
        warn <<-MSG unless @secrets.size >= 1
        SECURITY WARNING: No secret option provided to Rack::Session::Cookie.
        This poses a security threat. It is strongly recommended that you
        provide a secret to prevent exploits that may be possible from crafted
        cookies. This will not be supported in future versions of Rack, and
        future versions will even invalidate your existing user cookies.

        Called from: #{caller[0]}.
        MSG
        @coder = options[:coder] ||= Base64::Marshal.new
        @coder = Encrypted.new(@coder,options) if options[:cipher_key]
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
        env["rack.session.unpacked_cookie_data"] ||= begin
          request = Rack::Request.new(env)
          session_data = request.cookies[@key]

          if @secrets.size > 0 && session_data
            session_data, digest = session_data.split("--")
            session_data = nil unless digest_match?(session_data, digest)
          end

          coder.decode(session_data) || {}
        end
      end

      def persistent_session_id!(data, sid=nil)
        data ||= {}
        data["session_id"] ||= sid || generate_sid
        data
      end

      def set_session(env, session_id, session, options)
        session = session.merge("session_id" => session_id)
        session_data = coder.encode(session)

        if @secrets.first
          session_data << "--#{generate_hmac(session_data, @secrets.first)}"
        end

        if session_data.size > (4096 - @key.size)
          env["rack.errors"].puts("Warning! Rack::Session::Cookie data size exceeds 4K.")
          nil
        else
          session_data
        end
      end

      def destroy_session(env, session_id, options)
        # Nothing to do here, data is in the client
        generate_sid unless options[:drop]
      end

      def digest_match?(data, digest)
        return unless data && digest
        @secrets.any? do |secret|
          digest == generate_hmac(data, secret)
        end
      end

      def generate_hmac(data, secret)
        OpenSSL::HMAC.hexdigest(OpenSSL::Digest::SHA1.new, secret, data)
      end
    end
  end
end
