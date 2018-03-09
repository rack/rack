require 'minitest/autorun'
require 'rack'
require 'openssl'

describe Rack::Coders do

  it 'can be wrapped infinitely' do
    coder = Rack::Coders::HMAC.new(
      Rack::Coders::Base64.new(
        Rack::Coders::Cipher.new(
          Rack::Coders::JSON.new,
          secret: 'x' * 32
        )
      ),
      secret: 'y' * 32
    )
    data = { 'name' => 'John Doe' }
    coder.decode(coder.encode(data)).must_equal data
  end

  describe 'Base64' do
    let(:coder){ Rack::Coders::Base64.new }
    let(:nonstrict_coder){ Rack::Coders::Base64.new(strict: false) }

    it 'uses base64 to encode' do
      str   = 'fuuuuu'
      nonstrict_coder.encode(str).must_equal [str].pack('m')
    end

    it 'uses strict base64 to encode' do
      str   = 'fuuuuu'
      coder.encode(str).must_equal [str].pack('m0')
    end

    it 'uses base64 to decode' do
      str   = ['fuuuuu'].pack('m')
      nonstrict_coder.decode(str).must_equal str.unpack('m').first
    end

    it 'uses strict base64 to decode' do
      str   = ['fuuuuu'].pack('m0')
      coder.decode(str).must_equal str.unpack('m0').first
    end
  end

  describe 'Marshal' do
    let(:coder) { Rack::Coders::Marshal.new }

    it 'marshals encodes' do
      str   = 'fuuuuu'
      coder.encode(str).must_equal ::Marshal.dump(str)
    end

    it 'marshals decodes' do
      str   = ::Marshal.dump('fuuuuu')
      coder.decode(str).must_equal ::Marshal.load(str)
    end
  end

  describe 'JSON' do
    let(:coder) { Rack::Coders::JSON.new }

    it 'JSON encodes' do
      obj   = %w[fuuuuu]
      coder.encode(obj).must_equal ::JSON.dump(obj)
    end

    it 'JSON decodes' do
      str = '["fuuuuu"]'
      coder.decode(str).must_equal ::JSON.parse(str)
    end
  end

  describe 'Zip' do
    let(:coder) { Rack::Coders::Zip.new }

    it 'deflates' do
      str = 'fuuuuu'
      coder.encode(str).must_equal Zlib::Deflate.deflate(str)
    end

    it 'inflates' do
      str = 'fuuuuu'
      coder.decode(Zlib::Deflate.deflate(str)).must_equal str
    end
  end

  describe 'Rescue' do
    it 'rescues failures on decode' do
      Rack::Coders::Rescue.new(Rack::Coders::Zip.new).decode('lulz').must_be_nil
      Rack::Coders::Rescue.new(Rack::Coders::JSON.new).decode('lulz').must_be_nil
      Rack::Coders::Rescue.new(Rack::Coders::Marshal.new).decode('lulz').must_be_nil
    end
  end

  describe 'HMAC' do
    let(:secret) { 'top secret' }
    let(:coder) { Rack::Coders::HMAC.new secret: secret }

    it 'HMAC encodes' do
      str = 'hello'
      hmac = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), secret, str)
      assert_equal "hello--#{hmac}", coder.encode(str)
    end

    it 'HMAC decodes' do
      str = 'world'
      hmac = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), secret, str)
      assert_equal str, coder.decode("world--#{hmac}")
    end

    it 'raises InvalidSignature' do
      assert_raises Rack::Coders::HMAC::InvalidSignature do
        coder.decode('invalid encoding')
      end
    end

    it 'works with key rotation' do
      str = 'hello world'
      secret = 'x' * 100
      coder = Rack::Coders::HMAC.new secret: secret
      encoded = coder.encode(str)
      new_coder = Rack::Coders::HMAC.new secret: 'new secret', old_secret: secret
      assert_equal str, new_coder.decode(encoded)
    end
  end

  describe 'Cipher' do
    let(:coder) { Rack::Coders::Cipher.new secret: 'x' * 32 }

    it 'encrypts' do
      str = 'hello'
      encoded = coder.encode(str)
      assert_equal str, coder.decode(encoded)
    end

    it 'works with key rotation' do
      str = 'hello world'
      secret = 'x' * 32
      new_secret = 'y' * 32
      coder = Rack::Coders::Cipher.new secret: secret
      encoded = coder.encode(str)
      new_coder = Rack::Coders::Cipher.new secret: new_secret, old_secret: secret
      assert_equal str, new_coder.decode(encoded)
    end
  end
end
