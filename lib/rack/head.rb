module Rack

class Head
  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, body = @app.call(env)

    if env[Const::ENV_REQUEST_METHOD] == Const::HEAD
      [status, headers, []]
    else
      [status, headers, body]
    end
  end
end

end
