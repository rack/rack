# frozen_string_literal: true

require 'minitest/global_expectations/autorun'
require 'rack/session/abstract/id'

describe Rack::Session::Abstract::PersistedSecure::SecureSessionHash do
  attr_reader :hash

  def setup
    super
    @store = Class.new do
      def load_session(req)
        [Rack::Session::SessionId.new("id"), { foo: :bar, baz: :qux }]
      end
      def session_exists?(req)
        true
      end
    end
    @hash = Rack::Session::Abstract::PersistedSecure::SecureSessionHash.new(@store.new, nil)
  end

  it "returns keys" do
    assert_equal ["foo", "baz"], hash.keys
  end

  it "returns values" do
    assert_equal [:bar, :qux], hash.values
  end

  describe "#[]" do
    it "returns value for a matching key" do
      assert_equal :bar, hash[:foo]
    end

    it "returns value for a 'session_id' key" do
      assert_equal "id", hash['session_id']
    end

    it "returns nil value for missing 'session_id' key" do
      store = @store.new
      def store.load_session(req)
        [nil, {}]
      end
      @hash = Rack::Session::Abstract::PersistedSecure::SecureSessionHash.new(store, nil)
      assert_nil hash['session_id']
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
      assert_equal :default, hash.fetch(:unkown) { :default }
    end

    it "it raises when fetching unknown keys without defaults" do
      lambda { hash.fetch(:unknown) }.must_raise KeyError
    end
  end

  describe "#stringify_keys" do
    it "returns hash or session hash with keys stringified" do
      assert_equal({ "foo" => :bar, "baz" => :qux }, hash.send(:stringify_keys, hash).to_h)
    end
  end
end

