require 'rack/auth/basic'
require 'rack/lint'
require 'rack/mock'

describe Rack::Auth::Basic do
  def realm
    'WallysWorld'
  end

  def unprotected_app
    Rack::Lint.new lambda { |env|
      [ 200, {'Content-Type' => 'text/plain'}, ["Hi #{env['REMOTE_USER']}"] ]
    }
  end

  def protected_app
    app = Rack::Auth::Basic.new(unprotected_app) { |username, password| 'Boss' == username }
    app.realm = realm
    app
  end

  def protected_dir_app
    app = Rack::Auth::Basic.new(unprotected_app) do |username, password, request|
        request.instance_of?(Rack::Request).should.equal true
        /restaurant/i.match(request.path_info) && 'Zarniwoop' == username || /heart/i.match(request.path_info) && 'Marvin' == username
    end
    app.realm = realm
    app
  end

  before do
    @request = Rack::MockRequest.new(protected_app)
    @request_dir = Rack::MockRequest.new(protected_dir_app)
  end

  def request_with_basic_auth(username, password, &block)
    request 'HTTP_AUTHORIZATION' => 'Basic ' + ["#{username}:#{password}"].pack("m*"), &block
  end

  def request_dir_with_basic_auth(dir, username, password, &block)
    request_dir dir, 'HTTP_AUTHORIZATION' => 'Basic ' + ["#{username}:#{password}"].pack("m*"), &block
  end

  def request(headers = {})
    yield @request.get('/', headers)
  end

  def request_dir(dir, headers = {})
    yield @request_dir.get(dir, headers)
  end

  def assert_basic_auth_challenge(response)
    response.should.be.a.client_error
    response.status.should.equal 401
    response.should.include 'WWW-Authenticate'
    response.headers['WWW-Authenticate'].should =~ /Basic realm="#{Regexp.escape(realm)}"/
    response.body.should.be.empty
  end

  should 'challenge correctly when no credentials are specified' do
    request do |response|
      assert_basic_auth_challenge response
    end
  end

  should 'rechallenge if incorrect credentials are specified' do
    request_with_basic_auth 'joe', 'password' do |response|
      assert_basic_auth_challenge response
    end
  end

  should 'rechallenge if incorrect credentials are specified and an invalid request' do
    request_dir_with_basic_auth '/', 'joe', 'password' do |response|
      assert_basic_auth_challenge response
    end
  end

  should 'rechallenge if correct credentials are specified and an invalid request' do
    request_dir_with_basic_auth '/', 'Zarniwoop', 'password' do |response|
      assert_basic_auth_challenge response
    end
  end

  should 'rechallenge if incorrect credentials are specified and a valid request' do
    request_dir_with_basic_auth '/TheRestaurantattheEndoftheUniverse/', 'joe', 'password' do |response|
      assert_basic_auth_challenge response
    end
  end

  should 'rechallenge if incorrect credentials are specified for a valid request' do
    request_dir_with_basic_auth '/TheRestaurantattheEndoftheUniverse/', 'Marvin', 'password' do |response|
      assert_basic_auth_challenge response
    end
    request_dir_with_basic_auth '/HeartofGold/', 'Zarniwoop', 'password' do |response|
      assert_basic_auth_challenge response
    end
  end

  should 'return application output if correct credentials are specified' do
    request_with_basic_auth 'Boss', 'password' do |response|
      response.status.should.equal 200
      response.body.to_s.should.equal 'Hi Boss'
    end
  end

  should 'return application output if correct credentials are specified for valid request' do
    request_dir_with_basic_auth '/TheRestaurantattheEndoftheUniverse/', 'Zarniwoop', 'password' do |response|
      response.status.should.equal 200
      response.body.to_s.should.equal 'Hi Zarniwoop'
    end
    request_dir_with_basic_auth '/HeartofGold/', 'Marvin', 'password' do |response|
      response.status.should.equal 200
      response.body.to_s.should.equal 'Hi Marvin'
    end
  end

  should 'return 400 Bad Request if different auth scheme used' do
    request 'HTTP_AUTHORIZATION' => 'Digest params' do |response|
      response.should.be.a.client_error
      response.status.should.equal 400
      response.should.not.include 'WWW-Authenticate'
    end
  end

  it 'takes realm as optional constructor arg' do
    app = Rack::Auth::Basic.new(unprotected_app, realm) { true }
    realm.should == app.realm
  end
end
