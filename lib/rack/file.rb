# frozen_string_literal: true

require_relative 'files'

module Rack
  warn "Rack::File is deprecated and will be removed in Rack 3.1", uplevel: 1

  File = Files
end
