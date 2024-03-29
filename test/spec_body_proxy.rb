# frozen_string_literal: true

require_relative 'helper'

separate_testing do
  require_relative '../lib/rack/body_proxy'
end

describe Rack::BodyProxy do
  it 'call each on the wrapped body' do
    called = false
    proxy  = Rack::BodyProxy.new(['foo']) { }
    proxy.each do |str|
      called = true
      str.must_equal 'foo'
    end
    called.must_equal true
  end

  it 'call close on the wrapped body' do
    body  = StringIO.new
    proxy = Rack::BodyProxy.new(body) { }
    proxy.close
    body.must_be :closed?
  end

  it 'only call close on the wrapped body if it responds to close' do
    body  = []
    proxy = Rack::BodyProxy.new(body) { }
    proxy.close.must_be_nil
  end

  it 'call the passed block on close' do
    called = false
    proxy  = Rack::BodyProxy.new([]) { called = true }
    called.must_equal false
    proxy.close
    called.must_equal true
  end

  it 'call the passed block on close even if there is an exception' do
    object = Object.new
    def object.close() raise "No!" end
    called = false

    begin
      proxy = Rack::BodyProxy.new(object) { called = true }
      called.must_equal false
      proxy.close
    rescue RuntimeError => e
    end

    raise "Expected exception to have been raised" unless e
    called.must_equal true
  end

  it 'allow multiple arguments in respond_to?' do
    body  = []
    proxy = Rack::BodyProxy.new(body) { }
    proxy.respond_to?(:foo, false).must_equal false
  end

  it 'allows #method to work with delegated methods' do
    body  = Object.new
    def body.banana; :pear end
    proxy = Rack::BodyProxy.new(body) { }
    proxy.method(:banana).call.must_equal :pear
  end

  it 'allows calling delegated methods with keywords' do
    body  = Object.new
    def body.banana(foo: nil); foo end
    proxy = Rack::BodyProxy.new(body) { }
    proxy.banana(foo: 1).must_equal 1
  end

  it 'respond to :to_ary if body does responds to it, and have to_ary call close' do
    proxy_closed = false
    proxy = Rack::BodyProxy.new([]) { proxy_closed = true }
    proxy.respond_to?(:to_ary).must_equal true
    proxy_closed.must_equal false
    proxy.to_ary.must_equal []
    proxy_closed.must_equal true
  end

  it 'not respond to :to_ary if body does not respond to it' do
    proxy = Rack::BodyProxy.new([].map) { }
    proxy.respond_to?(:to_ary).must_equal false
    proc do
      proxy.to_ary
    end.must_raise NoMethodError
  end

  it 'not respond to :to_str' do
    proxy = Rack::BodyProxy.new("string body") { }
    proxy.respond_to?(:to_str).must_equal false
    proc do
      proxy.to_str
    end.must_raise NoMethodError
  end

  it 'not respond to :to_path if body does not respond to it' do
    proxy = Rack::BodyProxy.new("string body") { }
    proxy.respond_to?(:to_path).must_equal false
    proc do
      proxy.to_path
    end.must_raise NoMethodError
  end

  it 'not close more than one time' do
    count = 0
    proxy = Rack::BodyProxy.new([]) { count += 1; raise "Block invoked more than 1 time!" if count > 1 }
    2.times { proxy.close }
    count.must_equal 1
  end

  it 'be closed when the callback is triggered' do
    closed = false
    proxy = Rack::BodyProxy.new([]) { closed = proxy.closed? }
    proxy.close
    closed.must_equal true
  end
end
