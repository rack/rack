# frozen_string_literal: true

require_relative 'helper'
require 'rack/encryptor'
require 'rack/utils'

describe Rack::Encryptor do
  def setup
    @secret = SecureRandom.random_bytes(64)
  end

  it 'initialize does not destroy key string' do
    encryptor = Rack::Encryptor.new(@secret)

    @secret.size.must_equal 64
  end

  it 'initialize raises ArgumentError on invalid key' do
    lambda { Rack::Encryptor.new [:foo] }.must_raise ArgumentError
  end

  it 'initialize raises ArgumentError on short key' do
    lambda { Rack::Encryptor.new 'key' }.must_raise ArgumentError
  end

  it 'decrypts an encrypted message' do
    encryptor = Rack::Encryptor.new(@secret)

    message = encryptor.encrypt(foo: 'bar')

    encryptor.decrypt(message).must_equal foo: 'bar'
  end

  it 'decrypt raises InvalidSignature for tampered messages' do
    encryptor = Rack::Encryptor.new(@secret)

    message = encryptor.encrypt(foo: 'bar')

    decoded_message = Base64.urlsafe_decode64(message)
    tampered_message = Base64.urlsafe_encode64(decoded_message.tap { |m|
      m[m.size - 1] = (m[m.size - 1].unpack('C')[0] ^ 1).chr
    })

    lambda {
      encryptor.decrypt(tampered_message)
    }.must_raise Rack::Encryptor::InvalidSignature
  end

  it 'decrypts an encrypted message with purpose' do
    encryptor = Rack::Encryptor.new(@secret, purpose: 'testing')

    message = encryptor.encrypt(foo: 'bar')

    encryptor.decrypt(message).must_equal foo: 'bar'
  end

  it 'decrypts raises InvalidSignature without purpose' do
    encryptor = Rack::Encryptor.new(@secret, purpose: 'testing')
    other_encryptor = Rack::Encryptor.new(@secret)

    message = other_encryptor.encrypt(foo: 'bar')

    lambda { encryptor.decrypt(message) }.must_raise Rack::Encryptor::InvalidSignature
  end

  it 'decrypts raises InvalidSignature with different purpose' do
    encryptor = Rack::Encryptor.new(@secret, purpose: 'testing')
    other_encryptor = Rack::Encryptor.new(@secret, purpose: 'other')

    message = other_encryptor.encrypt(foo: 'bar')

    lambda { encryptor.decrypt(message) }.must_raise Rack::Encryptor::InvalidSignature
  end

  it 'initialize raises ArgumentError on invalid pad_size' do
    lambda { Rack::Encryptor.new @secret, pad_size: :bar }.must_raise ArgumentError
  end

  it 'initialize raises ArgumentError on to short pad_size' do
    lambda { Rack::Encryptor.new @secret, pad_size: 1 }.must_raise ArgumentError
  end

  it 'initialize raises ArgumentError on to long pad_size' do
    lambda { Rack::Encryptor.new @secret, pad_size: 8023 }.must_raise ArgumentError
  end

  it 'decrypts an encrypted message without pad_size' do
    encryptor = Rack::Encryptor.new(@secret, purpose: 'testing', pad_size: nil)

    message = encryptor.encrypt(foo: 'bar')

    encryptor.decrypt(message).must_equal foo: 'bar'
  end

  it 'encryptor with pad_size increases message size' do
    no_pad_encryptor = Rack::Encryptor.new(@secret, purpose: 'testing', pad_size: nil)
    pad_encryptor = Rack::Encryptor.new(@secret, purpose: 'testing', pad_size: 64)

    message_without = Base64.urlsafe_decode64(no_pad_encryptor.encrypt(''))
    message_with = Base64.urlsafe_decode64(pad_encryptor.encrypt(''))
    message_size_diff = message_with.bytesize - message_without.bytesize

    message_with.bytesize.must_be :>, message_without.bytesize
    message_size_diff.must_equal 64 - Marshal.dump('').bytesize - 2
  end

  it 'encryptor with pad_size has message payload size to multiple of pad_size' do
    encryptor = Rack::Encryptor.new(@secret, purpose: 'testing', pad_size: 24)
    message = encryptor.encrypt(foo: 'bar' * 4)

    decoded_message = Base64.urlsafe_decode64(message)

    # slice 1 byte for version, 32 bytes for cipher_secret, 16 bytes for IV
    # from the start of the string and 32 bytes at the end of the string
    encrypted_payload = decoded_message[(1 + 32 + 16)..-33]

    (encrypted_payload.bytesize % 24).must_equal 0
  end

  # This test checks the one-time message key IS NOT used as the cipher key.
  # Doing so would remove the confidentiality assurances as the key is
  # essentially included in plaintext then.
  it 'uses a secret cipher key for encryption and decryption' do
    cipher = OpenSSL::Cipher.new('aes-256-ctr')
    encryptor = Rack::Encryptor.new(@secret)

    message = encryptor.encrypt(foo: 'bar')
    raw_message = Base64.urlsafe_decode64(message)

    ver = raw_message.slice!(0, 1)
    key = raw_message.slice!(0, 32)
    iv = raw_message.slice!(0, 16)

    cipher.decrypt
    cipher.key = key
    cipher.iv = iv

    data = cipher.update(raw_message) << cipher.final

    # "data" should now be random bytes because we tried to decrypt a message
    # with the wrong key

    padding_bytes, = data.unpack('v') # likely a large number
    serialized_data = data.slice(2 + padding_bytes, data.bytesize) # likely nil

    lambda { Marshal.load serialized_data }.must_raise TypeError
  end

  it 'it calls set_cipher_key with the correct key' do
    encryptor = Rack::Encryptor.new(@secret, purpose: 'testing', pad_size: 24)
    message = encryptor.encrypt(foo: 'bar')

    message_key = Base64.urlsafe_decode64(message).slice(1, 32)

    callable = proc do |cipher, key|
      key.wont_equal @secret
      key.wont_equal message_key

      cipher.key = key
    end

    encryptor.stub :set_cipher_key, callable do
      encryptor.decrypt message
    end
  end
end
