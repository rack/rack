# frozen_string_literal: true

require_relative 'helper'

separate_testing do
  require_relative '../lib/rack/server_timing'
  require_relative '../lib/rack/lint'
  require_relative '../lib/rack/mock_request'
end

describe Rack::ServerTiming do
  def server_timing_app(app, *args)
    Rack::Lint.new Rack::ServerTiming.new(app, *args)
  end

  def request
    Rack::MockRequest.env_for
  end

  it "sets server-timing header with rack-runtime metric" do
    app = lambda { |env| [200, { 'content-type' => 'text/plain' }, "Hello, World!"] }
    response = server_timing_app(app).call(request)
    response[1]['server-timing'].must_match(/\Arack-runtime;dur=[\d\.]+\z/)
  end

  it "appends to existing server-timing header" do
    app = lambda { |env| [200, { 'content-type' => 'text/plain', 'server-timing' => 'view;dur=50.0' }, "Hello, World!"] }
    response = server_timing_app(app).call(request)
    response[1]['server-timing'].must_match(/\Aview;dur=50\.0, rack-runtime;dur=[\d\.]+\z/)
  end

  it "sets server-timing metric with custom name" do
    app = lambda { |env| [200, { 'content-type' => 'text/plain' }, "Hello, World!"] }
    response = server_timing_app(app, "db").call(request)
    response[1]['server-timing'].must_match(/\Adb;dur=[\d\.]+\z/)
  end
end
