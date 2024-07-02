# frozen_string_literal: true

require_relative 'helper'

separate_testing do
  require_relative '../lib/rack/logger'
  require_relative '../lib/rack/lint'
  require_relative '../lib/rack/mock_request'
end

describe Rack::Logger do
  app = lambda { |env|
    log = env['rack.logger']
    log.debug("Created logger")
    log.info("Program started")
    log.warn("Nothing to do!")

    [200, { 'content-type' => 'text/plain' }, ["Hello, World!"]]
  }

  it "conform to Rack::Lint" do
    errors = StringIO.new
    a = Rack::Lint.new(Rack::Logger.new(app, Rack::Logger::Output.new(errors)))
    Rack::MockRequest.new(a).get('/')
    errors.string.must_match(/Program started/)
    errors.string.must_match(/Nothing to do/)
  end
end
