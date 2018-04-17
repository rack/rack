#!/usr/bin/env ruby
# frozen_string_literal: true

# -*- ruby -*-

require 'uri'
$:.unshift '../../lib'
require 'rack'
require '../testrequest'

Rack::Handler::FastCGI.run(Rack::Lint.new(TestRequest.new))
