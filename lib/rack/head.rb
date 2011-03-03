require 'rack/middleware'
module Rack

class Head < Rack::Middleware
  def call(env)
    status, headers, body = super

    if env["REQUEST_METHOD"] == "HEAD"
      [status, headers, []]
    else
      [status, headers, body]
    end
  end
end

end
