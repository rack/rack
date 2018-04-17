#!/usr/bin/env ruby
# frozen_string_literal: true

require 'uri'
$:.unshift '../../lib'
require 'rack'
require '../testrequest'

Rack::Handler::FastCGI.run(Rack::Lint.new(TestRequest.new))
