module Rack
  class MethodOverride
    HTTP_METHODS = %w(GET HEAD PUT POST DELETE OPTIONS PATCH)

    METHOD_OVERRIDE_PARAM_KEY = "_method".freeze
    HTTP_METHOD_OVERRIDE_HEADER = "HTTP_X_HTTP_METHOD_OVERRIDE".freeze

    attr_reader :trusted_original_methods

    def initialize(app, trusted_original_methods=["POST"])
      @app = app
      @trusted_original_methods = trusted_original_methods
    end

    def call(env)
      if trusted_method?(env)
        method = method_override(env)
        if HTTP_METHODS.include?(method)
          env["rack.methodoverride.original_method"] = env["REQUEST_METHOD"]
          env["REQUEST_METHOD"] = method
        end
      end

      @app.call(env)
    end

    def trusted_method?(env)
      trusted_original_methods.include? env["REQUEST_METHOD"]
    end

    def method_override(env)
      req = Request.new(env)
      method = overide_param(req) if trusted_method?(env)
      method = overide_header(env) unless method
      method.to_s.upcase
    rescue EOFError
      ""
    end

    def overide_param(req)
      req.GET[METHOD_OVERRIDE_PARAM_KEY] ||
        req.POST[METHOD_OVERRIDE_PARAM_KEY]
    end

    def overide_header(env)
      env[HTTP_METHOD_OVERRIDE_HEADER]
    end
  end
end
