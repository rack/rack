# frozen_string_literal: true

require_relative 'helper'
require 'rack/session/abstract/id'

describe Rack::Session::Abstract::Persisted do
  def setup
    @class = Rack::Session::Abstract::Persisted
    @pers = @class.new(nil)
  end

  it "#generated_sid generates a session identifier" do
    @pers.send(:generate_sid).must_match(/\A\h+\z/)
    @pers.send(:generate_sid, nil).must_match(/\A\h+\z/)

    obj = Object.new
    def obj.hex(_); raise NotImplementedError end
    @pers.send(:generate_sid, obj).must_match(/\A\h+\z/)
  end

  it "#commit_session? returns false if :skip option is given" do
    @pers.send(:commit_session?, Rack::Request.new({}), {}, skip: true).must_equal false
  end

  it "#commit_session writes to rack.errors if session cannot be written" do
    @pers = @class.new(nil)
    def @pers.write_session(*) end
    errors = StringIO.new
    env = { 'rack.errors' => errors }
    req = Rack::Request.new(env)
    store = Class.new do
      def load_session(req)
        ["id", {}]
      end
      def session_exists?(req)
        true
      end
    end
    session = env['rack.session'] = Rack::Session::Abstract::SessionHash.new(store.new, req)
    session['foo'] = 'bar'
    @pers.send(:commit_session, req, Rack::Response.new)
    errors.rewind
    errors.read.must_equal "Warning! Rack::Session::Abstract::Persisted failed to save session. Content dropped.\n"
  end

  it "#cookie_value returns its argument" do
    obj = Object.new
    @pers.send(:cookie_value, obj).must_equal(obj)
  end

  it "#session_class returns the default session class" do
    @pers.send(:session_class).must_equal Rack::Session::Abstract::SessionHash
  end

  it "#find_session raises" do
    proc { @pers.send(:find_session, nil, nil) }.must_raise RuntimeError
  end

  it "#write_session raises" do
    proc { @pers.send(:write_session, nil, nil, nil, nil) }.must_raise RuntimeError
  end

  it "#delete_session raises" do
    proc { @pers.send(:delete_session, nil, nil, nil) }.must_raise RuntimeError
  end
end
