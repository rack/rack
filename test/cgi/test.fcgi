#!/usr/bin/env ruby
# -*- ruby -*-

$: << File.join(File.dirname(__FILE__), "..", "..", "lib")

require 'rack'
require '../testrequest'

Rack::Handler::FastCGI.run(Rack::Lint.new(TestRequest.new))
