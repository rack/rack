require 'rack/files'

module Rack
  # Rack::File is deprecated, please use Rack::Files instead
  File = Files
end
