# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022-2023, by Samuel Williams.

warn "Rack::Handler is deprecated and replaced by Rackup::Handler"
begin
  require 'rackup'
rescue LoadError => e
  warn "You don't have the `rackup` gem installed. Please add it to your Gemfile and run bundle install"
  exit
end

module Rack
	Handler = ::Rackup::Handler
end
