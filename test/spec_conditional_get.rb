# frozen_string_literal: true

require 'minitest/autorun'
require 'time'
require 'rack/conditional_get'
require 'rack/mock'

describe Rack::ConditionalGet do
  def conditional_get(app)
    Rack::Lint.new Rack::ConditionalGet.new(app)
  end

  def instance_get(app)
    Rack::ConditionalGet.new(app)
  end

  it "set a 304 status and truncate body when If-Modified-Since hits" do
    timestamp = Time.now.httpdate
    app = conditional_get(lambda { |env|
      [200, { 'Last-Modified' => timestamp }, ['TEST']] })

    response = Rack::MockRequest.new(app).
      get("/", 'HTTP_IF_MODIFIED_SINCE' => timestamp)

    response.status.must_equal 304
    response.body.must_be :empty?
  end

  it "set a 304 status and truncate body when If-Modified-Since hits and is higher than current time" do
    app = conditional_get(lambda { |env|
      [200, { 'Last-Modified' => (Time.now - 3600).httpdate }, ['TEST']] })

    response = Rack::MockRequest.new(app).
      get("/", 'HTTP_IF_MODIFIED_SINCE' => Time.now.httpdate)

    response.status.must_equal 304
    response.body.must_be :empty?
  end

  it "set a 304 status and truncate body when If-None-Match hits" do
    app = conditional_get(lambda { |env|
      [200, { 'ETag' => '1234' }, ['TEST']] })

    response = Rack::MockRequest.new(app).
      get("/", 'HTTP_IF_NONE_MATCH' => '1234')

    response.status.must_equal 304
    response.body.must_be :empty?
  end

  it "not set a 304 status if If-Modified-Since hits but Etag does not" do
    timestamp = Time.now.httpdate
    app = conditional_get(lambda { |env|
      [200, { 'Last-Modified' => timestamp, 'Etag' => '1234', 'Content-Type' => 'text/plain' }, ['TEST']] })

    response = Rack::MockRequest.new(app).
      get("/", 'HTTP_IF_MODIFIED_SINCE' => timestamp, 'HTTP_IF_NONE_MATCH' => '4321')

    response.status.must_equal 200
    response.body.must_equal 'TEST'
  end

  it "set a 304 status and truncate body when both If-None-Match and If-Modified-Since hits" do
    timestamp = Time.now.httpdate
    app = conditional_get(lambda { |env|
      [200, { 'Last-Modified' => timestamp, 'ETag' => '1234' }, ['TEST']] })

    response = Rack::MockRequest.new(app).
      get("/", 'HTTP_IF_MODIFIED_SINCE' => timestamp, 'HTTP_IF_NONE_MATCH' => '1234')

    response.status.must_equal 304
    response.body.must_be :empty?
  end

  it "not affect non-GET/HEAD requests" do
    app = conditional_get(lambda { |env|
      [200, { 'Etag' => '1234', 'Content-Type' => 'text/plain' }, ['TEST']] })

    response = Rack::MockRequest.new(app).
      post("/", 'HTTP_IF_NONE_MATCH' => '1234')

    response.status.must_equal 200
    response.body.must_equal 'TEST'
  end

  it "not affect non-200 requests" do
    app = conditional_get(lambda { |env|
      [302, { 'Etag' => '1234', 'Content-Type' => 'text/plain' }, ['TEST']] })

    response = Rack::MockRequest.new(app).
      get("/", 'HTTP_IF_NONE_MATCH' => '1234')

    response.status.must_equal 302
    response.body.must_equal 'TEST'
  end

  it "not affect requests with malformed HTTP_IF_NONE_MATCH" do
    bad_timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S %z')
    app = conditional_get(lambda { |env|
      [200, { 'Last-Modified' => (Time.now - 3600).httpdate, 'Content-Type' => 'text/plain' }, ['TEST']] })

    response = Rack::MockRequest.new(app).
      get("/", 'HTTP_IF_MODIFIED_SINCE' => bad_timestamp)

    response.status.must_equal 200
    response.body.must_equal 'TEST'
  end

  describe 'private method' do
    it "fresh? using without any header" do
      instance = instance_get(lambda { |env| [200, {}, []]})
      instance.send(:fresh?, {}, {}).must_equal false
    end
    it "fresh? using HTTP_IF_NONE_MATCH and Etag" do
      instance = instance_get(lambda { |env| [200, {}, []]})
      instance.send(:fresh?, {
                      'HTTP_IF_NONE_MATCH' => '1234'
                    }, {
                      'ETag' => '1234'
                    }).must_equal true
      assert_nil instance.send(:fresh?, {
                      'HTTP_IF_NONE_MATCH' => '4321'
                    }, {
                      'Etag' => '1234'
                    })
    end
    it "fresh? using If-Modified-Since and Last-Modified" do
      current = Time.now.httpdate
      previous_time = (Time.now - 10000).httpdate
      future_time = (Time.now + 10000).httpdate
      instance = instance_get(lambda { |env| [200, {}, []]})
      instance.send(:fresh?, {
                      'HTTP_IF_MODIFIED_SINCE' => previous_time
                    }, {
                      'Last-Modified' => current
                    }).must_equal false
      instance.send(:fresh?, {
                      'HTTP_IF_MODIFIED_SINCE' => future_time
                    }, {
                      'Last-Modified' => current
                    }).must_equal true
    end

    it "to_rfc2822 " do
      instance = instance_get(lambda { |env| [200, {}, []]})
      assert_nil instance.send(:to_rfc2822, ('wrong time string'))
      # Not RFC 2822 compliant date
      assert_nil instance.send(:to_rfc2822, Time.now.gmtime.to_s)
      instance.send(:to_rfc2822, Time.now.httpdate).must_equal Time.rfc2822(Time.now.httpdate)
    end

    it "etag_matches?" do
      instance = instance_get(lambda { |env| [200, {}, []]})
      instance.send(:etag_matches?, '1234', { 'ETag' => '1234' }).must_equal true
      instance.send(:etag_matches?, '1234', { 'ETag' => '1233' }).must_equal false
    end

    it "modified_since?" do
      current = Time.now.httpdate
      previous_time = (Time.now - 10000).httpdate
      future_time = (Time.now + 10000).httpdate
      instance = instance_get(lambda { |env| [200, {}, []]})
      instance.send(:modified_since?, Time.rfc2822(current), { 'Last-Modified' => current }).must_equal true
      instance.send(:modified_since?, Time.rfc2822(future_time), { 'Last-Modified' => current }).must_equal true
      instance.send(:modified_since?, Time.rfc2822(previous_time), { 'Last-Modified' => current }).must_equal false
    end
  end
end
