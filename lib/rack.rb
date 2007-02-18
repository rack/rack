# Copyright (C) 2007 Christian Neukirchen <purl.org/net/chneukirchen>
#
# Rack is freely distributable under the terms of an MIT-style license.
# See COPYING or http://www.opensource.org/licenses/mit-license.php.

$: << File.expand_path(File.dirname(__FILE__))

module Rack
  VERSION = [0,1]

  def self.version
    VERSION.join(".")
  end

  autoload :Lint, "rack/lint"
  autoload :File, "rack/file"
  autoload :Utils, "rack/utils"
  autoload :ShowExceptions, "rack/showexceptions"
  autoload :URLMap, "rack/urlmap"
  autoload :CommonLogger, "rack/commonlogger"

  autoload :Request, "rack/request"
  autoload :Response, "rack/response"

  module Handler
    autoload :CGI, "rack/handler/cgi"
    autoload :Mongrel, "rack/handler/mongrel"
    autoload :WEBrick, "rack/handler/webrick"
  end
end

