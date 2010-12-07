module Rack
  # This module contains frozen singleton copies of all Rack specific environment variable names.
  module RACK_VARIABLE
    ERRORS = "rack.errors".freeze
    INPUT = "rack.input".freeze
    LOGGER = "rack.logger".freeze
    METHODOVERRIDE_ORIGINAL_METHOD = 'rack.methodoverride.original_method'.freeze
    MULTIPROCESS = "rack.multiprocess".freeze
    MULTITHREAD = "rack.multithread".freeze
    RECURSIVE_INCLUDE = 'rack.recursive.include'.freeze
    REQUEST_COOKIE_HASH = "rack.request.cookie_hash".freeze
    REQUEST_COOKIE_STRING = "rack.request.cookie_string".freeze
    REQUEST_FORM_HASH = "rack.request.form_hash".freeze
    REQUEST_FORM_INPUT = "rack.request.form_input".freeze
    REQUEST_FORM_VARS = "rack.request.form_vars".freeze
    REQUEST_QUERY_HASH = "rack.request.query_hash".freeze
    REQUEST_QUERY_STRING = "rack.request.query_string".freeze
    RUN_ONCE = "rack.run_once".freeze
    SESSION = "rack.session".freeze
    SESSION_OPTIONS = "rack.session.options".freeze
    SESSION_UNPACKED_COOKIE_DATA = "rack.session.unpacked_cookie_data".freeze
    SHOWSTATUS_DETAIL = "rack.showstatus.detail".freeze
    URL_SCHEME = "rack.url_scheme".freeze
    VERSION = "rack.version".freeze
  end
end
