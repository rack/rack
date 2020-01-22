# frozen_string_literal: true

require 'minitest/global_expectations/autorun'
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
    @hash = Rack::Session::Abstract::SessionHash.new(store.new, nil)
  end

  it "returns keys" do
    assert_equal ["foo", "baz", "x"], hash.keys
  end

  it "returns values" do
    assert_equal [:bar, :qux, { y: 1 }], hash.values
  end

  describe "#dig" do
    it "operates like Hash#dig" do
      assert_equal({ y: 1 }, hash.dig("x"))
      assert_equal(1, hash.dig(:x, :y))
      assert_nil(hash.dig(:z))
      assert_nil(hash.dig(:x, :z))
      lambda { hash.dig(:x, :y, :z) }.must_raise TypeError
      lambda { hash.dig }.must_raise ArgumentError
    end
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

  describe "#stringify_keys" do
    it "returns hash or session hash with keys stringified" do
      assert_equal({ "foo" => :bar, "baz" => :qux, "x" => { y: 1 } }, hash.send(:stringify_keys, hash).to_h)
    end
  end
end
