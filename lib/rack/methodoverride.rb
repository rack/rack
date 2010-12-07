module Rack
  class MethodOverride
    HTTP_METHOD_LIST = %w(GET HEAD PUT POST DELETE OPTIONS)

    METHOD_OVERRIDE_PARAM_KEY = "_method".freeze
    HTTP_METHOD_OVERRIDE_HEADER = "HTTP_X_HTTP_METHOD_OVERRIDE".freeze

    def initialize(app)
      @app = app
    end

    def call(env)
      if env[CGI_VARIABLE::REQUEST_METHOD] == HTTP_METHOD::POST
        req = Request.new(env)
        method = req.POST[METHOD_OVERRIDE_PARAM_KEY] ||
          env[HTTP_METHOD_OVERRIDE_HEADER]
        method = method.to_s.upcase
        if HTTP_METHOD_LIST.include?(method)
          env[RACK_VARIABLE::METHODOVERRIDE_ORIGINAL_METHOD] = env[CGI_VARIABLE::REQUEST_METHOD]
          env[CGI_VARIABLE::REQUEST_METHOD] = method
        end
      end

      @app.call(env)
    end
  end
end
