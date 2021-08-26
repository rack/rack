# frozen_string_literal: true

require_relative 'helper'
### WARNING: there be hax in this file.

require 'rack/session/abstract/id'

describe Rack::Session::Abstract::ID do
  attr_reader :id

  def setup
    super
    @id = Rack::Session::Abstract::ID
  end

  it "use securerandom" do
    assert_equal ::SecureRandom, id::DEFAULT_OPTIONS[:secure_random]

    id = @id.new nil
    assert_equal ::SecureRandom, id.sid_secure
  end

  it "allow to use another securerandom provider" do
    secure_random = Class.new do
      def hex(*args)
        'fake_hex'
      end
    end
    id = Rack::Session::Abstract::ID.new nil, secure_random: secure_random.new
    id.send(:generate_sid).must_equal 'fake_hex'
  end

  it "should warn when subclassing" do
    verbose = $VERBOSE
    begin
      $VERBOSE = true
      warn_arg = nil
      @id.define_singleton_method(:warn) do |arg|
        warn_arg = arg
      end
      c = Class.new(@id)
      regexp = /is inheriting from Rack::Session::Abstract::ID.  Inheriting from Rack::Session::Abstract::ID is deprecated, please inherit from Rack::Session::Abstract::Persisted instead/
      warn_arg.must_match(regexp)

      warn_arg = nil
      c = Class.new(c)
      warn_arg.must_be_nil
    ensure
      $VERBOSE = verbose
      @id.singleton_class.send(:remove_method, :warn)
    end
  end

  it "#find_session should find session in request" do
    id = @id.new(nil)
    def id.get_session(env, sid)
      [env['rack.session'], generate_sid]
    end
    req = Rack::Request.new('rack.session' => {})
    session, sid = id.find_session(req, nil)
    session.must_equal({})
    sid.must_match(/\A\h+\z/)
  end

  it "#write_session should write session to request" do
    id = @id.new(nil)
    def id.set_session(env, sid, session, options)
      [env, sid, session, options]
    end
    req = Rack::Request.new({})
    id.write_session(req, 1, 2, 3).must_equal [{}, 1, 2, 3]
  end

  it "#delete_session should remove session from request" do
    id = @id.new(nil)
    def id.destroy_session(env, sid, options)
      [env, sid, options]
    end
    req = Rack::Request.new({})
    id.delete_session(req, 1, 2).must_equal [{}, 1, 2]
  end
end
