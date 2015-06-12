require 'minitest/bacon'
### WARNING: there be hax in this file.

require 'rack/session/abstract/id'

describe Rack::Session::Abstract::ID do
  i_suck_and_my_tests_are_order_dependent!

  id = Rack::Session::Abstract::ID

  def silence_warning
    o, $VERBOSE = $VERBOSE, nil
    yield
  ensure
    $VERBOSE = o
  end

  should "use securerandom" do
    id::DEFAULT_OPTIONS[:secure_random].should.eql(SecureRandom)

    id = id.new nil
    assert_equal ::SecureRandom, id.sid_secure
  end

  should "allow to use another securerandom provider" do
    secure_random = Class.new do
      def hex(*args)
        'fake_hex'
      end
    end
    id = Rack::Session::Abstract::ID.new nil, :secure_random => secure_random.new
    id.send(:generate_sid).should.eql 'fake_hex'
  end

end
