#!../../bin/rackup
# frozen_string_literal: true

require '../test_request'
run Rack::Lint.new(TestRequest.new)
