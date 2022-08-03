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

require_relative 'rack/version'
require_relative 'rack/constants'

module Rack
  autoload :Builder, "rack/builder"
  autoload :BodyProxy, "rack/body_proxy"
  autoload :Cascade, "rack/cascade"
  autoload :Chunked, "rack/chunked"
  autoload :CommonLogger, "rack/common_logger"
  autoload :ConditionalGet, "rack/conditional_get"
  autoload :Config, "rack/config"
  autoload :ContentLength, "rack/content_length"
  autoload :ContentType, "rack/content_type"
  autoload :ETag, "rack/etag"
  autoload :Events, "rack/events"
  autoload :File, "rack/file"
  autoload :Files, "rack/files"
  autoload :Deflater, "rack/deflater"
  autoload :Directory, "rack/directory"
  autoload :ForwardRequest, "rack/recursive"
  autoload :Handler, "rack/handler"
  autoload :Head, "rack/head"
  autoload :Headers, "rack/headers"
  autoload :Lint, "rack/lint"
  autoload :Lock, "rack/lock"
  autoload :Logger, "rack/logger"
  autoload :MediaType, "rack/media_type"
  autoload :MethodOverride, "rack/method_override"
  autoload :Mime, "rack/mime"
  autoload :NullLogger, "rack/null_logger"
  autoload :Recursive, "rack/recursive"
  autoload :Reloader, "rack/reloader"
  autoload :RewindableInput, "rack/rewindable_input"
  autoload :Runtime, "rack/runtime"
  autoload :Sendfile, "rack/sendfile"
  autoload :Server, "rack/server"
  autoload :ShowExceptions, "rack/show_exceptions"
  autoload :ShowStatus, "rack/show_status"
  autoload :Static, "rack/static"
  autoload :TempfileReaper, "rack/tempfile_reaper"
  autoload :URLMap, "rack/urlmap"
  autoload :Utils, "rack/utils"
  autoload :Multipart, "rack/multipart"

  autoload :MockRequest, "rack/mock_request"
  autoload :MockResponse, "rack/mock_response"

  autoload :Request, "rack/request"
  autoload :Response, "rack/response"

  module Auth
    autoload :Basic, "rack/auth/basic"
    autoload :AbstractRequest, "rack/auth/abstract/request"
    autoload :AbstractHandler, "rack/auth/abstract/handler"
    autoload :Digest, "rack/auth/digest"
  end
end
