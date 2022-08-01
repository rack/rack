# frozen_string_literal: true

require_relative 'helper'

separate_testing do
  require_relative '../lib/rack/content_type'
  require_relative '../lib/rack/lint'
  require_relative '../lib/rack/mock_request'
end

describe Rack::ContentType do
  def content_type(app, *args)
    Rack::Lint.new Rack::ContentType.new(app, *args)
  end

  def request
    Rack::MockRequest.env_for
  end

  it "set content-type to default text/html if none is set" do
    app = lambda { |env| [200, {}, "Hello, World!"] }
    headers = content_type(app).call(request)[1]
    headers['content-type'].must_equal 'text/html'
  end

  it "set content-type to chosen default if none is set" do
    app = lambda { |env| [200, {}, "Hello, World!"] }
    headers =
      content_type(app, 'application/octet-stream').call(request)[1]
    headers['content-type'].must_equal 'application/octet-stream'
  end

  it "not change content-type if it is already set" do
    app = lambda { |env| [200, { 'content-type' => 'foo/bar' }, "Hello, World!"] }
    headers = content_type(app).call(request)[1]
    headers['content-type'].must_equal 'foo/bar'
  end

  [100, 204, 304].each do |code|
    it "not set content-type on #{code} responses" do
      app = lambda { |env| [code, {}, []] }
      response = content_type(app, "text/html").call(request)
      response[1]['content-type'].must_be_nil
    end
  end
end
