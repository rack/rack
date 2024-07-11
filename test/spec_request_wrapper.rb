# frozen_string_literal: true

require_relative 'helper'

separate_testing do
  require_relative '../lib/rack/request_wrapper'
  require_relative '../lib/rack/lint'
  require_relative '../lib/rack/mock_request'
end

describe Rack::RequestWrapper do
  def request_wrapper(app)
    Rack::RequestWrapper.new(app)
  end

  def request
    Rack::MockRequest.env_for
  end

  it "converts the request env to a request object" do
    app = lambda {|env| [200, {}, [env.class.to_s]]}

    response = request_wrapper(app).call(request)
    response[0].must_equal 200
    response[1].must_equal({})
    response[2].must_equal ["Rack::Request"]
  end
end
