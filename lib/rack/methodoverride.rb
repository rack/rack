module Rack
  class MethodOverride
    HTTP_METHODS = %w(GET HEAD PUT POST DELETE OPTIONS)

    METHOD_OVERRIDE_PARAM_KEY = "_method".freeze
    HTTP_METHOD_OVERRIDE_HEADER = "HTTP_X_HTTP_METHOD_OVERRIDE".freeze

    def initialize(app)
      @app = app
    end

    def call(env)
      if env[Const::ENV_REQUEST_METHOD] == Const::POST
        req = Request.new(env)
        method = req.POST[METHOD_OVERRIDE_PARAM_KEY] ||
          env[HTTP_METHOD_OVERRIDE_HEADER]
        method = method.to_s.upcase
        if HTTP_METHODS.include?(method)
          env["rack.methodoverride.original_method"] = env[Const::ENV_REQUEST_METHOD]
          env[Const::ENV_REQUEST_METHOD] = method
        end
      end

      @app.call(env)
    end
  end
end
