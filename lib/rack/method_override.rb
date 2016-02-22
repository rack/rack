module Rack
  class MethodOverride
    HTTP_METHODS = %w[GET HEAD PUT POST DELETE OPTIONS PATCH LINK UNLINK]

    METHOD_OVERRIDE_PARAM_KEY = "_method".freeze
    HTTP_METHOD_OVERRIDE_HEADER = "HTTP_X_HTTP_METHOD_OVERRIDE".freeze
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
        env[HTTP_METHOD_OVERRIDE_HEADER]
      method.to_s.upcase
    end

    private

    def allowed_methods
      ALLOWED_METHODS
    end

    def method_override_param(req)
      req.POST[METHOD_OVERRIDE_PARAM_KEY]
    rescue Utils::InvalidParameterError => e
      warn "Invalid Parameter: #{e.message}"
    rescue Utils::ParameterTypeError => e
      warn "Invalid Parameter Type: #{e.message}"
    end
  end
end
