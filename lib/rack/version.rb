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
  VERSION = String.new("3.0.0")

  def VERSION.join(separator)
    warn "Rack::Version is now a String, use it directly!", uplevel: 1
    VERSION.split('.').join(separator)
  end

  def VERSION.[](index)
    warn "Rack::Version is now a String, use it directly!", uplevel: 1
    VERSION.split('.')[index]
  end

  VERSION.freeze

  # Return the Rack protocol version as a dotted string.
  def self.version
    # In a future release, say, 3.1?
    # warn "Rack::VERSION is now a String, use it directly!", uplevel: 1
    VERSION
  end

  RELEASE = VERSION
  deprecate_constant :RELEASE
  
  # Return the Rack release as a dotted string.
  def self.release
    # In a future release, say, 3.1?
    # warn "Rack::VERSION is now a String, use it directly!", uplevel: 1
    VERSION
  end
end
