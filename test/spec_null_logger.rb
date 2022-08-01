# frozen_string_literal: true

require_relative 'helper'

separate_testing do
  require_relative '../lib/rack/null_logger'
  require_relative '../lib/rack/lint'
  require_relative '../lib/rack/mock_request'
end

describe Rack::NullLogger do
  it "act as a noop logger" do
    app = lambda { |env|
      env['rack.logger'].warn "b00m"
      [200, { 'content-type' => 'text/plain' }, ["Hello, World!"]]
    }

    logger = Rack::Lint.new(Rack::NullLogger.new(app))

    res = logger.call(Rack::MockRequest.env_for)
    res[0..1].must_equal [
      200, { 'content-type' => 'text/plain' }
    ]
    res[2].to_enum.to_a.must_equal ["Hello, World!"]
  end
end
