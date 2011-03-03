require 'rack/middleware'
module Rack
  class MethodOverride < Rack::Middleware
    HTTP_METHODS = %w(GET HEAD PUT POST DELETE OPTIONS)

    METHOD_OVERRIDE_PARAM_KEY = "_method".freeze
    HTTP_METHOD_OVERRIDE_HEADER = "HTTP_X_HTTP_METHOD_OVERRIDE".freeze

    def call(env)
      if env["REQUEST_METHOD"] == "POST"
        req = Request.new(env)
        method = req.POST[METHOD_OVERRIDE_PARAM_KEY] ||
          env[HTTP_METHOD_OVERRIDE_HEADER]
        method = method.to_s.upcase
        if HTTP_METHODS.include?(method)
          env["rack.methodoverride.original_method"] = env["REQUEST_METHOD"]
          env["REQUEST_METHOD"] = method
        end
      end

      super
    end
  end
end
