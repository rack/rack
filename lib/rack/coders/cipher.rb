# frozen_string_literal: true

require 'rack/coders/coder'
require 'openssl'

module Rack
  module Coders
    # Encrypt the data into this format:
    #
    #     "#{encrypted_data}--#{initial_vector}"
    #
    class Cipher < Coder
      def initialize(coder = nil, secret:, old_secret: nil, cipher: 'AES-256-CBC')
        super(coder)
        @secret = secret
        @old_secret = old_secret
        @cipher = OpenSSL::Cipher.new(cipher)
      end

      def encode(obj)
        @cipher.encrypt
        @cipher.key = @secret
        iv = @cipher.random_iv
        encrypted_data = @cipher.update(coder.encode(obj)) << @cipher.final
        "#{[encrypted_data].pack('m0')}--#{[iv].pack('m0')}"
      end

      def decode(data)
        secrets = [@old_secret, @secret]
        until secrets.empty?
          secret = secrets.pop
          begin
            encrypted_data, iv = data.split('--').map! { |v| v.unpack('m0').first }
            @cipher.decrypt
            @cipher.key = secret
            @cipher.iv  = iv
            return coder.decode(@cipher.update(encrypted_data) << @cipher.final)
          rescue StandardError
            secrets.empty? ? raise : next
          end
        end
      end
    end
  end
end
