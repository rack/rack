# frozen_string_literal: true

require_relative 'constants'
require_relative 'request'
require_relative 'utils'

module Rack
  class MethodOverride
    HTTP_METHODS = %w[GET HEAD PUT POST DELETE OPTIONS PATCH LINK UNLINK QUERY]

    PRIV_HTTP_METHODS = HTTP_METHODS
    private_constant :PRIV_HTTP_METHODS
    deprecate_constant :HTTP_METHODS

    # QUERY is excluded from _method parameter overrides by default:
    # frameworks CSRF-exempt QUERY because HTML forms cannot emit it, and
    # the _method parameter is reachable from a plain form POST. The
    # X-HTTP-Method-Override header is not — cross-origin, custom headers
    # always force a CORS preflight — so QUERY remains overridable there.
    PARAM_EXCLUDED_METHODS = %w[QUERY]
    private_constant :PARAM_EXCLUDED_METHODS

    METHOD_OVERRIDE_PARAM_KEY = "_method"
    HTTP_METHOD_OVERRIDE_HEADER = "HTTP_X_HTTP_METHOD_OVERRIDE"
    ALLOWED_METHODS = %w[POST]

    PRIV_ALLOWED_METHODS = ALLOWED_METHODS
    private_constant :PRIV_ALLOWED_METHODS
    deprecate_constant :ALLOWED_METHODS

    def initialize(app, allowed_methods: PRIV_ALLOWED_METHODS, allowed_overrides: PRIV_HTTP_METHODS,
                   allowed_param_overrides: allowed_overrides - PARAM_EXCLUDED_METHODS)
      @app = app
      @allowed_methods = allowed_methods
      @allowed_overrides = allowed_overrides
      @allowed_param_overrides = allowed_param_overrides
    end

    def call(env)
      if allowed_methods.include?(env[REQUEST_METHOD])
        method = method_override(env)
        if allowed_overrides_for(env).include?(method)
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

    attr_reader :allowed_methods, :allowed_overrides, :allowed_param_overrides

    # The _method parameter answers to the narrower parameter policy; the
    # X-HTTP-Method-Override header to the full one. Probes the form hash
    # that method_override's Request#POST call cached in the env rather
    # than parsing the body a second time (which would also duplicate any
    # parse-error messages written to rack.errors).
    def allowed_overrides_for(env)
      if (form = env[RACK_REQUEST_FORM_HASH]) && form[METHOD_OVERRIDE_PARAM_KEY]
        allowed_param_overrides
      else
        allowed_overrides
      end
    end

    def method_override_param(req)
      req.POST[METHOD_OVERRIDE_PARAM_KEY] if req.form_data? || req.parseable_data?
    rescue Utils::InvalidParameterError, Utils::ParameterTypeError, QueryParser::ParamsTooDeepError, QueryParser::IncompatibleEncodingError
      req.get_header(RACK_ERRORS).puts "Invalid or incomplete POST params"
    rescue EOFError
      req.get_header(RACK_ERRORS).puts "Bad request content body"
    end
  end
end
