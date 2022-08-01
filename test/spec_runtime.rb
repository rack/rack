# frozen_string_literal: true

require_relative 'helper'

separate_testing do
  require_relative '../lib/rack/runtime'
  require_relative '../lib/rack/lint'
  require_relative '../lib/rack/mock_request'
end

describe Rack::Runtime do
  def runtime_app(app, *args)
    Rack::Lint.new Rack::Runtime.new(app, *args)
  end

  def request
    Rack::MockRequest.env_for
  end

  it "sets x-runtime is none is set" do
    app = lambda { |env| [200, { 'content-type' => 'text/plain' }, "Hello, World!"] }
    response = runtime_app(app).call(request)
    response[1]['x-runtime'].must_match(/[\d\.]+/)
  end

  it "doesn't set the x-runtime if it is already set" do
    app = lambda { |env| [200, { 'content-type' => 'text/plain', "x-runtime" => "foobar" }, "Hello, World!"] }
    response = runtime_app(app).call(request)
    response[1]['x-runtime'].must_equal "foobar"
  end

  it "allow a suffix to be set" do
    app = lambda { |env| [200, { 'content-type' => 'text/plain' }, "Hello, World!"] }
    response = runtime_app(app, "Test").call(request)
    response[1]['x-runtime-test'].must_match(/[\d\.]+/)
  end

  it "allow multiple timers to be set" do
    app = lambda { |env| sleep 0.1; [200, { 'content-type' => 'text/plain' }, "Hello, World!"] }
    runtime = runtime_app(app, "App")

    # wrap many times to guarantee a measurable difference
    100.times do |i|
      runtime = Rack::Runtime.new(runtime, i.to_s)
    end
    runtime = Rack::Runtime.new(runtime, "All")

    response = runtime.call(request)

    response[1]['x-runtime-app'].must_match(/[\d\.]+/)
    response[1]['x-runtime-all'].must_match(/[\d\.]+/)

    Float(response[1]['x-runtime-all']).must_be :>, Float(response[1]['x-runtime-app'])
  end
end
