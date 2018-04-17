# frozen_string_literal: true

# -*- ruby -*-

require '../testrequest'

run Rack::Lint.new(TestRequest.new)
