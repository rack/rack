module Rack
  class MethodOverride
    HTTP_METHODS = %w[GET HEAD PUT POST DELETE OPTIONS PATCH LINK UNLINK]

    METHOD_OVERRIDE_PARAM_KEY = "_method".freeze
    HTTP_METHOD_OVERRIDE_HEADER_DEPRECATED = "HTTP_X_HTTP_METHOD_OVERRIDE".freeze
    HTTP_METHOD_OVERRIDE_HEADER = "X-HTTP-Method-Override".freeze
    ALLOWED_METHODS = %w[POST]

    def initialize(app)
      @app = app
    end

    def call(env)
      if allowed_methods.include?(env[REQUEST_METHOD])
        method = method_override(env)
        if HTTP_METHODS.include?(method)
          env[RACK_METHODOVERRIDE_ORIGINAL_METHOD] = env[REQUEST_METHOD]
          env[REQUEST_METHOD] = method
        end
      end

      @app.call(env)
    end

    def method_override(env)
      req = Request.new(env)
      method = method_override_param(req) ||
        method_override_header(env)
      method.to_s.upcase
    end

    private

    def allowed_methods
      ALLOWED_METHODS
    end

    def method_override_header(env)
      if env[HTTP_METHOD_OVERRIDE_HEADER_DEPRECATED]
        if logger = env[RACK_LOGGER]
          logger.warn "Deprecation notice: #{HTTP_METHOD_OVERRIDE_HEADER_DEPRECATED} header is deprecated and will be removed. Please use #{HTTP_METHOD_OVERRIDE_HEADER} for HTTP method override."
        end
        env[HTTP_METHOD_OVERRIDE_HEADER_DEPRECATED]
      else
        env[HTTP_METHOD_OVERRIDE_HEADER]
      end
    end

    def method_override_param(req)
      req.POST[METHOD_OVERRIDE_PARAM_KEY]
    rescue Utils::InvalidParameterError, Utils::ParameterTypeError
      req.get_header(RACK_ERRORS).puts "Invalid or incomplete POST params"
    rescue EOFError
      req.get_header(RACK_ERRORS).puts "Bad request content body"
    end
  end
end
