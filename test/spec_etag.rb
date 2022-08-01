# frozen_string_literal: true

require_relative 'helper'
require 'time'

separate_testing do
  require_relative '../lib/rack/etag'
  require_relative '../lib/rack/lint'
  require_relative '../lib/rack/mock_request'
end

describe Rack::ETag do
  def etag(app, *args)
    Rack::Lint.new Rack::ETag.new(app, *args)
  end

  def request
    Rack::MockRequest.env_for
  end

  def sendfile_body
    File.new(File::NULL)
  end

  it "set etag if none is set if status is 200" do
    app = lambda { |env| [200, { 'content-type' => 'text/plain' }, ["Hello, World!"]] }
    response = etag(app).call(request)
    response[1]['etag'].must_equal "W/\"dffd6021bb2bd5b0af676290809ec3a5\""
  end

  it "set etag if none is set if status is 201" do
    app = lambda { |env| [201, { 'content-type' => 'text/plain' }, ["Hello, World!"]] }
    response = etag(app).call(request)
    response[1]['etag'].must_equal "W/\"dffd6021bb2bd5b0af676290809ec3a5\""
  end

  it "set cache-control to 'max-age=0, private, must-revalidate' (default) if none is set" do
    app = lambda { |env| [201, { 'content-type' => 'text/plain' }, ["Hello, World!"]] }
    response = etag(app).call(request)
    response[1]['cache-control'].must_equal 'max-age=0, private, must-revalidate'
  end

  it "set cache-control to chosen one if none is set" do
    app = lambda { |env| [201, { 'content-type' => 'text/plain' }, ["Hello, World!"]] }
    response = etag(app, nil, 'public').call(request)
    response[1]['cache-control'].must_equal 'public'
  end

  it "set a given cache-control even if digest could not be calculated" do
    app = lambda { |env| [200, { 'content-type' => 'text/plain' }, []] }
    response = etag(app, 'no-cache').call(request)
    response[1]['cache-control'].must_equal 'no-cache'
  end

  it "not set cache-control if it is already set" do
    app = lambda { |env| [201, { 'content-type' => 'text/plain', 'cache-control' => 'public' }, ["Hello, World!"]] }
    response = etag(app).call(request)
    response[1]['cache-control'].must_equal 'public'
  end

  it "not set cache-control if directive isn't present" do
    app = lambda { |env| [200, { 'content-type' => 'text/plain' }, ["Hello, World!"]] }
    response = etag(app, nil, nil).call(request)
    response[1]['cache-control'].must_be_nil
  end

  it "not change etag if it is already set" do
    app = lambda { |env| [200, { 'content-type' => 'text/plain', 'etag' => '"abc"' }, ["Hello, World!"]] }
    response = etag(app).call(request)
    response[1]['etag'].must_equal "\"abc\""
  end

  it "not set etag if body is empty" do
    app = lambda { |env| [200, { 'content-type' => 'text/plain', 'last-modified' => Time.now.httpdate }, []] }
    response = etag(app).call(request)
    response[1]['etag'].must_be_nil
  end

  it "set handle empty body parts" do
    app = lambda { |env| [200, { 'content-type' => 'text/plain' }, ["Hello", "", ", World!"]] }
    response = etag(app).call(request)
    response[1]['etag'].must_equal "W/\"dffd6021bb2bd5b0af676290809ec3a5\""
  end

  it "not set etag if last-modified is set" do
    app = lambda { |env| [200, { 'content-type' => 'text/plain', 'last-modified' => Time.now.httpdate }, ["Hello, World!"]] }
    response = etag(app).call(request)
    response[1]['etag'].must_be_nil
  end

  it "not set etag if a sendfile_body is given" do
    app = lambda { |env| [200, { 'content-type' => 'text/plain' }, sendfile_body] }
    response = etag(app).call(request)
    response[1]['etag'].must_be_nil
  end

  it "not set etag if a status is not 200 or 201" do
    app = lambda { |env| [401, { 'content-type' => 'text/plain' }, ['Access denied.']] }
    response = etag(app).call(request)
    response[1]['etag'].must_be_nil
  end

  it "set etag even if no-cache is given" do
    app = lambda { |env| [200, { 'content-type' => 'text/plain', 'cache-control' => 'no-cache, must-revalidate' }, ['Hello, World!']] }
    response = etag(app).call(request)
    response[1]['etag'].must_equal "W/\"dffd6021bb2bd5b0af676290809ec3a5\""
  end

  it "close the original body" do
    body = StringIO.new
    app = lambda { |env| [200, {}, body] }
    response = etag(app).call(request)
    body.wont_be :closed?
    response[2].close
    body.must_be :closed?
  end
end
