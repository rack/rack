# frozen_string_literal: true

require_relative 'helper'

separate_testing do
  require_relative '../lib/rack/content_length'
  require_relative '../lib/rack/lint'
  require_relative '../lib/rack/mock_request'
end

describe Rack::ContentLength do
  def content_length(app)
    Rack::Lint.new Rack::ContentLength.new(app)
  end

  def request
    Rack::MockRequest.env_for
  end

  it "set content-length on Array bodies if none is set" do
    app = lambda { |env| [200, { 'content-type' => 'text/plain' }, ["Hello, World!"]] }
    response = content_length(app).call(request)
    response[1]['content-length'].must_equal '13'
  end

  it "not set content-length on variable length bodies" do
    body = lambda { "Hello World!" }
    def body.each ; yield call ; end

    app = lambda { |env| [200, { 'content-type' => 'text/plain' }, body] }
    response = content_length(app).call(request)
    response[1]['content-length'].must_be_nil
  end

  it "not change content-length if it is already set" do
    app = lambda { |env| [200, { 'content-type' => 'text/plain', 'content-length' => '1' }, "Hello, World!"] }
    response = content_length(app).call(request)
    response[1]['content-length'].must_equal '1'
  end

  it "not set content-length on 304 responses" do
    app = lambda { |env| [304, {}, []] }
    response = content_length(app).call(request)
    response[1]['content-length'].must_be_nil
  end

  it "not set content-length when transfer-encoding is chunked" do
    app = lambda { |env| [200, { 'content-type' => 'text/plain', 'transfer-encoding' => 'chunked' }, []] }
    response = content_length(app).call(request)
    response[1]['content-length'].must_be_nil
  end

  # Using "Connection: close" for this is fairly contended. It might be useful
  # to have some other way to signal this.
  #
  # should "not force a content-length when Connection:close" do
  #   app = lambda { |env| [200, {'Connection' => 'close'}, []] }
  #   response = content_length(app).call({})
  #   response[1]['content-length'].must_be_nil
  # end

  it "close bodies that need to be closed" do
    body = Struct.new(:body) do
      attr_reader :closed
      def each; body.each {|b| yield b}; close; end
      def close; @closed = true; end
      def to_ary; enum_for.to_a; end
    end.new(%w[one two three])

    app = lambda { |env| [200, { 'content-type' => 'text/plain' }, body] }
    content_length(app).call(request)
    body.closed.must_equal true
  end

  it "support single-execute bodies" do
    body = Struct.new(:body) do
      def each
        yield body.shift until body.empty?
      end
      def to_ary; enum_for.to_a; end
    end.new(%w[one two three])

    app = lambda { |env| [200, { 'content-type' => 'text/plain' }, body] }
    response = content_length(app).call(request)
    expected = %w[one two three]
    response[1]['content-length'].must_equal expected.join.size.to_s
    response[2].to_enum.to_a.must_equal expected
  end
end
