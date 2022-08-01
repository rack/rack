# frozen_string_literal: true

warn "require 'rack/mock' is deprecated and will be removed in Rack 3.1, use require 'rack/mock_request' instead.", uplevel: 1
require_relative 'mock_request'
