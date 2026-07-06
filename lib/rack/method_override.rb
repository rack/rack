# frozen_string_literal: true

require_relative 'constants'
require_relative 'request'
require_relative 'utils'

module Rack
  class MethodOverride
    HTTP_METHODS = %w[GET HEAD PUT POST DELETE OPTIONS PATCH LINK UNLINK]

    PRIV_HTTP_METHODS = HTTP_METHODS
    private_constant :PRIV_HTTP_METHODS
    deprecate_constant :HTTP_METHODS

    METHOD_OVERRIDE_PARAM_KEY = "_method"
    HTTP_METHOD_OVERRIDE_HEADER = "HTTP_X_HTTP_METHOD_OVERRIDE"
    ALLOWED_METHODS = %w[POST]

    PRIV_ALLOWED_METHODS = ALLOWED_METHODS
    private_constant :PRIV_ALLOWED_METHODS
    deprecate_constant :ALLOWED_METHODS

    def initialize(app, allowed_methods: PRIV_ALLOWED_METHODS, allowed_overrides: PRIV_HTTP_METHODS)
      @app = app
      @allowed_methods = allowed_methods
      @allowed_overrides = allowed_overrides
    end

    def call(env)
      if allowed_methods.include?(env[REQUEST_METHOD])
        method = method_override(env)
        if allowed_overrides.include?(method)
          env[RACK_METHODOVERRIDE_ORIGINAL_METHOD] = env[REQUEST_METHOD]
          env[REQUEST_METHOD] = method
        end
      end

      @app.call(env)
    end

    def method_override(env)
      req = Request.new(env)
      method = method_override_param(req) ||
        env[HTTP_METHOD_OVERRIDE_HEADER]
      begin
        method.to_s.upcase
      rescue ArgumentError
        env[RACK_ERRORS].puts "Invalid string for method"
      end
    end

    private

    attr_reader :allowed_methods, :allowed_overrides

    def method_override_param(req)
      req.POST[METHOD_OVERRIDE_PARAM_KEY] if req.form_data? || req.parseable_data?
    rescue Utils::InvalidParameterError, Utils::ParameterTypeError, QueryParser::ParamsTooDeepError, QueryParser::IncompatibleEncodingError
      req.get_header(RACK_ERRORS).puts "Invalid or incomplete POST params"
    rescue EOFError
      req.get_header(RACK_ERRORS).puts "Bad request content body"
    end
  end
end
