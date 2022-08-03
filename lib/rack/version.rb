# frozen_string_literal: true

# Copyright (C) 2007-2019 Leah Neukirchen <http://leahneukirchen.org/infopage.html>
#
# Rack is freely distributable under the terms of an MIT-style license.
# See MIT-LICENSE or https://opensource.org/licenses/MIT.

# The Rack main module, serving as a namespace for all core Rack
# modules and classes.
#
# All modules meant for use in your application are <tt>autoload</tt>ed here,
# so it should be enough just to <tt>require 'rack'</tt> in your code.

module Rack
  # The Rack protocol version number implemented.
  VERSION = [1, 3].freeze
  deprecate_constant :VERSION

  VERSION_STRING = "1.3".freeze
  deprecate_constant :VERSION_STRING

  # The Rack protocol version number implemented.
  def self.version
    warn "Rack.version is deprecated and will be removed in Rack 3.1!", uplevel: 1
    VERSION
  end

  RELEASE = "3.0.0"

  # Return the Rack release as a dotted string.
  def self.release
    RELEASE
  end
end
