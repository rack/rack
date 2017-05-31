require 'rack/auth/abstract/handler'
require 'rack/auth/abstract/request'

module Rack
  module Auth
    # Rack::Auth::Basic implements HTTP Basic Authentication, as per RFC 2617.
    #
    # Initialize with the Rack application that you want protecting,
    # and a block that checks if a username and password pair are valid.
    #
    # See also: <tt>example/protectedlobster.rb</tt>
    class Basic < AbstractHandler
      def call(env)
        auth = Basic::Request.new(env)

        return unauthorized unless auth.provided?
        return bad_request  unless auth.basic?
        return unauthorized unless valid?(auth)

        env['REMOTE_USER'] = auth.username
        @app.call(env)
      end

      private

      def challenge
        %{Basic realm="#{realm}"}
      end

      def valid?(auth)
        @authenticator.call(*auth.credentials)
      end

      class Request < Auth::AbstractRequest # :nodoc:
        BASIC = "basic".freeze

        def basic?
          scheme == BASIC
        end

        def credentials
          @credentials ||= params.unpack("m*").first.split(/:/, 2)
        end

        def username
          credentials.first
        end
      end
    end
  end
end
