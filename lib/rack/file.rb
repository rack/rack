# frozen_string_literal: true

require 'rack/files'

module Rack
  warn "Rack::File is deprecated, please use Rack::Files instead."
  File = Files
end
