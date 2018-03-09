# frozen_string_literal: true

require 'rack/coders/coder'
require 'openssl'

module Rack
  module Coders
    # Actuall, it doesn't encode but appends a hex HMAC to the input data
    # in this format:
    #
    #     "#{data}--#{hmac}"
    #
    class HMAC < Coder
      class InvalidSignature < StandardError; end

      REGEXP = /\A(.*)--(.*)\z/

      def initialize(coder = nil, secret:, old_secret: nil, digest: 'SHA1')
        super(coder)
        @secret = secret
        @old_secret = old_secret
        @digest = ::OpenSSL::Digest.new(digest)
      end

      def encode(str)
        data = coder.encode(str)
        hmac = generate_hmac(@secret, data)
        "#{data}--#{hmac}"
      end

      def decode(str)
        match_data = REGEXP.match(str)
        data, hmac = match_data.captures if match_data
        secrets = [@secret, @old_secret]
        raise InvalidSignature unless data && hmac && secrets.any? { |secret| secure_compare(hmac, generate_hmac(secret, data)) }
        coder.decode(data)
      end

      private

      def generate_hmac(secret, str)
        ::OpenSSL::HMAC.hexdigest(@digest.new, secret, str)
      end

      def secure_compare(a, b) # rubocop:disable Naming/UncommunicativeMethodParamName
        return false unless a.bytesize == b.bytesize
        l = a.unpack('C*')
        r = 0
        i = -1
        b.each_byte { |v| r |= v ^ l[i += 1] }
        r.zero?
      end
    end
  end
end
