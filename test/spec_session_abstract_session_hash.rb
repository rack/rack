# frozen_string_literal: true

require_relative 'helper'
require 'rack/session/abstract/id'

describe Rack::Session::Abstract::SessionHash do
  attr_reader :hash

  def setup
    super
    store = Class.new do
      def load_session(req)
        ["id", { foo: :bar, baz: :qux, x: { y: 1 } }]
      end
      def session_exists?(req)
        true
      end
    end
    @class = Rack::Session::Abstract::SessionHash
    @hash = @class.new(store.new, nil)
  end

  it ".find finds entry in request" do
    assert_equal({}, @class.find(Rack::Request.new('rack.session' => {})))
  end

  it ".set sets session in request" do
    req = Rack::Request.new({})
    @class.set(req, {})
    req.env['rack.session'].must_equal({})
  end

  it ".set_options sets session options in request" do
    req = Rack::Request.new({})
    h = {}
    @class.set_options(req, h)
    opts = req.env['rack.session.options']
    opts.must_equal(h)
    opts.wont_be_same_as(h)
  end

  it "#keys returns keys" do
    assert_equal ["foo", "baz", "x"], hash.keys
  end

  it "#values returns values" do
    assert_equal [:bar, :qux, { y: 1 }], hash.values
  end

  it "#dig operates like Hash#dig" do
    assert_equal({ y: 1 }, hash.dig("x"))
    assert_equal(1, hash.dig(:x, :y))
    assert_nil(hash.dig(:z))
    assert_nil(hash.dig(:x, :z))
    lambda { hash.dig(:x, :y, :z) }.must_raise TypeError
    lambda { hash.dig }.must_raise ArgumentError
  end

  it "#each iterates over entries" do
    a = []
    @hash.each do |k, v|
      a << [k, v]
    end
    a.must_equal [["foo", :bar], ["baz", :qux], ["x", { y: 1 }]]
  end

  it "#has_key returns whether the key is in the hash" do
    assert_equal true, hash.has_key?("foo")
    assert_equal true, hash.has_key?(:foo)
    assert_equal false, hash.has_key?("food")
    assert_equal false, hash.has_key?(:food)
  end

  it "#replace replaces hash" do
    hash.replace({ bar: "foo" })
    assert_equal "foo", hash["bar"]
  end

  describe "#fetch" do
    it "returns value for a matching key" do
      assert_equal :bar, hash.fetch(:foo)
    end

    it "works with a default value" do
      assert_equal :default, hash.fetch(:unknown, :default)
    end

    it "works with a block" do
      assert_equal :default, hash.fetch(:unknown) { :default }
    end

    it "it raises when fetching unknown keys without defaults" do
      lambda { hash.fetch(:unknown) }.must_raise KeyError
    end
  end

  it "#stringify_keys returns hash or session hash with keys stringified" do
    assert_equal({ "foo" => :bar, "baz" => :qux, "x" => { y: 1 } }, hash.send(:stringify_keys, hash).to_h)
  end
end
