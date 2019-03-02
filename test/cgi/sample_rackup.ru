# frozen_string_literal: true

require '../testrequest'

run Rack::Lint.new(TestRequest.new)
