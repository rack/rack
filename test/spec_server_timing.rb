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
    response[1]['server-timing'].must_match(/^rack-runtime;dur=[\d\.]+$/)
  end

  it "appends to existing server-timing header" do
    app = lambda { |env| [200, { 'content-type' => 'text/plain', 'server-timing' => 'view;dur=50.0' }, "Hello, World!"] }
    response = server_timing_app(app).call(request)
    response[1]['server-timing'].must_match(/^view;dur=50\.0, rack-runtime;dur=[\d\.]+$/)
  end

  it "sets server-timing metric with custom name" do
    app = lambda { |env| [200, { 'content-type' => 'text/plain' }, "Hello, World!"] }
    response = server_timing_app(app, "db").call(request)
    response[1]['server-timing'].must_match(/^db;dur=[\d\.]+$/)
  end

  it "allows multiple timers to be set" do
    app = lambda { |env| sleep 0.1; [200, { 'content-type' => 'text/plain' }, "Hello, World!"] }
    server_timing = server_timing_app(app, "db")

    # wrap many times to guarantee a measurable difference
    100.times do |i|
      server_timing = Rack::ServerTiming.new(server_timing, "t#{i}")
    end
    server_timing = Rack::ServerTiming.new(server_timing, "total")

    response = server_timing.call(request)
    server_timing_header = response[1]['server-timing']

    # Verify total value is greater than db value
    db_duration = server_timing_header.match(/db;dur=([\d\.]+)/)[1]
    total_duration = server_timing_header.match(/total;dur=([\d\.]+)/)[1]
    Float(total_duration).must_be :>, Float(db_duration)

    # Verify all other timers are present
    100.times do |i|
      server_timing_header.must_match(/t#{i};dur=[\d\.]+/)
    end
  end
end
