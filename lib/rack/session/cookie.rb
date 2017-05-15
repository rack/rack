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

    class Cookie < Abstract::Persisted
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

        # N.B. Unlike other encoding methods, the contained objects must be a
        # valid JSON composite type, either a Hash or an Array.
        class JSON < Base64
          def encode(obj)
            super(::JSON.dump(obj))
          end

          def decode(str)
            return unless str
            ::JSON.parse(super(str)) rescue nil
          end
        end

        class ZipJSON < Base64
          def encode(obj)
            super(Zlib::Deflate.deflate(::JSON.dump(obj)))
          end

          def decode(str)
            return unless str
            ::JSON.parse(Zlib::Inflate.inflate(super(str)))
          rescue
            nil
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
              warn <<-XXX
              SECURITY WARNING: Cookie encryption has been disabled because: #{$!.message}
              XXX
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
              warn <<-XXX
              SECURITY WARNING: Cookie encryption has been disabled because: #{$!.message}
              XXX
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
        @coder = options[:coder] ||= Base64::Marshal.new
        @coder = Encrypted.new(@coder,options) if options[:cipher_key]
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
