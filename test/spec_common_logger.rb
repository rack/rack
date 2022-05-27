# frozen_string_literal: true

require_relative 'helper'
require 'logger'

describe Rack::CommonLogger do
  obj = 'foobar'
  length = obj.size

  app = Rack::Lint.new lambda { |env|
    [200,
     { "Content-Type" => "text/html", "Content-Length" => length.to_s },
     [obj]]}
  app_without_length = Rack::Lint.new lambda { |env|
    [200,
     { "Content-Type" => "text/html" },
     []]}
  app_with_zero_length = Rack::Lint.new lambda { |env|
    [200,
     { "Content-Type" => "text/html", "Content-Length" => "0" },
     []]}
  app_without_lint = lambda { |env|
    [200,
     { "content-type" => "text/html", "content-length" => length.to_s },
     [obj]]}

  it "log to rack.errors by default" do
    res = Rack::MockRequest.new(Rack::CommonLogger.new(app)).get("/")

    res.errors.wont_be :empty?
    res.errors.must_match(/"GET \/ " 200 #{length} /)
  end

  it "log to anything with +write+" do
    log = StringIO.new
    Rack::MockRequest.new(Rack::CommonLogger.new(app, log)).get("/")

    log.string.must_match(/"GET \/ " 200 #{length} /)
  end

  it "work with standard library logger" do
    logdev = StringIO.new
    log = Logger.new(logdev)
    Rack::MockRequest.new(Rack::CommonLogger.new(app, log)).get("/")

    logdev.string.must_match(/"GET \/ " 200 #{length} /)
  end

  it "log - content length if header is missing" do
    res = Rack::MockRequest.new(Rack::CommonLogger.new(app_without_length)).get("/")

    res.errors.wont_be :empty?
    res.errors.must_match(/"GET \/ " 200 - /)
  end

  it "log - content length if header is zero" do
    res = Rack::MockRequest.new(Rack::CommonLogger.new(app_with_zero_length)).get("/")

    res.errors.wont_be :empty?
    res.errors.must_match(/"GET \/ " 200 - /)
  end

  def with_mock_time(t = 0)
    mc = class << Time; self; end
    mc.send :alias_method, :old_now, :now
    mc.send :define_method, :now do
      at(t)
    end
    yield
  ensure
    mc.send :undef_method, :now
    mc.send :alias_method, :now, :old_now
  end

  it "log in common log format" do
    log = StringIO.new
    with_mock_time do
      Rack::MockRequest.new(Rack::CommonLogger.new(app, log)).get("/")
    end

    md = /- - - \[([^\]]+)\] "(\w+) \/ " (\d{3}) \d+ ([\d\.]+)/.match(log.string)
    md.wont_equal nil
    time, method, status, duration = *md.captures
    time.must_equal Time.at(0).strftime("%d/%b/%Y:%H:%M:%S %z")
    method.must_equal "GET"
    status.must_equal "200"
    (0..1).must_include duration.to_f
  end

  it "escapes non printable characters except newline" do
    logdev = StringIO.new
    log = Logger.new(logdev)
    Rack::MockRequest.new(Rack::CommonLogger.new(app_without_lint, log)).request("GET\b", "/hello")

    logdev.string.must_match(/GET\\x8 \/hello/)
  end

  it "log path with PATH_INFO" do
    logdev = StringIO.new
    log = Logger.new(logdev)
    Rack::MockRequest.new(Rack::CommonLogger.new(app, log)).get("/hello")

    logdev.string.must_match(/"GET \/hello " 200 #{length} /)
  end

  it "log path with SCRIPT_NAME" do
    logdev = StringIO.new
    log = Logger.new(logdev)
    Rack::MockRequest.new(Rack::CommonLogger.new(app, log)).get("/path", script_name: "/script")

    logdev.string.must_match(/"GET \/script\/path " 200 #{length} /)
  end

  def length
    123
  end

  def self.obj
    "hello world"
  end
end
