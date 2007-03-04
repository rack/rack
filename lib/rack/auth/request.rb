module Rack
  module Auth
    class Request
      
      def initialize(env)
        @env = env
      end

      def provided?
        !authorization_key.nil?
      end

      def authorization
        @authorization ||= @env[authorization_key].split
      end

      def is?(scheme)
        scheme == authorization.first.to_sym
      end

      def credentials
        @credentials ||= Base64.decode64(encoded_credentials).split(/:/, 2)
      end

      def username
        credentials.first
      end

      def password
        credentials.last
      end


      private

      def encoded_credentials
        authorization.last
      end

      AUTHORIZATION_KEYS = ['HTTP_AUTHORIZATION', 'X-HTTP_AUTHORIZATION', 'X_HTTP_AUTHORIZATION']

      def authorization_key
        @authorization_key ||= AUTHORIZATION_KEYS.detect { |key| @env.has_key?(key) }
      end

    end
  end
end