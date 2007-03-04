require 'test/spec'
require 'rack/mock'
require 'rack/auth/basic'
require 'base64'

context 'Rack::Auth::Basic' do

  REALM = 'WallysWorld'
  
  ORIGINAL_APP = lambda do |env|
    [ 200, {'Content-Type' => 'text/plain'}, ["Hi #{env['REMOTE_USER']}"] ]
  end
  
  setup do
    @request = Rack::MockRequest.new(
      Rack::Auth::Basic.new(ORIGINAL_APP, :realm => REALM) { |user, pass| 'Boss' == user }
    )
  end

  def request_with_basic_auth(path, username, password, &block)
    request path, 'HTTP_AUTHORIZATION' => 'Basic ' + Base64.encode64("#{username}:#{password}"), &block
  end

  def request(path, headers = {})
    yield @request.get(path, headers)
  end

  def assert_basic_auth_challenge(response)
    response.should.be.a.client_error
    response.status.should.equal 401
    response.should.include 'WWW-Authenticate'
    response.headers['WWW-Authenticate'].should.equal 'Basic realm="%s"' % REALM
    response.should =~ /401 Unauthorized/
  end

  specify 'should fail on initialization if no realm is provided' do
    initialization_without_realm = lambda { Rack::Auth::Basic.new(ORIGINAL_APP) { } }
    initialization_without_realm.should.raise ArgumentError
  end

  specify 'should challenge correctly when no credentials are specified' do
    request '/' do |response|
      assert_basic_auth_challenge response
    end
  end

  specify 'should rechallenge if incorrect credentials are specified' do
    request_with_basic_auth '/', 'joe', 'password' do |response|
      assert_basic_auth_challenge response
    end
  end

  specify 'should return application output if correct credentials are specified' do
    request_with_basic_auth '/', 'Boss', 'password' do |response|
      response.status.should.equal 200
      response.body.to_s.should.equal 'Hi Boss'
    end
  end

end
