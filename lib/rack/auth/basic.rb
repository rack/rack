require 'rack/auth/abstract/handler'
require 'rack/auth/abstract/request'

module Rack
  module Auth
    class Basic < AbstractHandler

      def call(env)
        auth = Basic::Request.new(env)

        return unauthorized unless auth.provided?

        return bad_request unless auth.basic?

        if valid?(auth)
          env['REMOTE_USER'] = auth.username

          return @app.call(env)
        end

        unauthorized
      end


      private

      def challenge
        'Basic realm="%s"' % realm
      end

      def valid?(auth)
        @authenticator.call(*auth.credentials)
      end

      class Request < Auth::AbstractRequest
        def basic?
          :basic == scheme
        end

        def credentials
          @credentials ||= Base64.decode64(params).split(/:/, 2)
        end

        def username
          credentials.first
        end
      end

    end
  end
end
