module Rack
  module Auth
    class AbstractHandler

      attr_accessor :realm

      def initialize(app, &authenticator)
        @app, @authenticator = app, authenticator
      end

      def unauthorized(www_authenticate = challenge)
        headers = {
          'Content-Type' => 'text/html',
          'WWW-Authenticate' => www_authenticate.to_s
        }
        return [ 401, headers, ['<h1>401 Unauthorized</h1>'] ]
      end

      def bad_request
        [ 400, { 'Content-Type' => 'text/html' }, ['<h1>400 Bad Request</h1>'] ]
      end

    end
  end
end
