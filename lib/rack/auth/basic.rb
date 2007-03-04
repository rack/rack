require 'base64'
require 'rack/auth/request'

module Rack
  module Auth
    class Basic
      
      def initialize(app, options = {}, &authenticator)
        unless options.has_key?(:realm)
          raise ArgumentError, 'no realm specified'
        end
  
        @app, @options, @authenticator = app, options, authenticator
      end
  
      def call(env)
        auth = Auth::Request.new(env)
        
        if auth.provided? && auth.is?(:Basic) && valid?(auth.credentials)
          env['REMOTE_USER'] = auth.username
          
          return @app.call(env)
        end
  
        return challenge_response
      end
  
  
      private
  
      def challenge_response
        headers = {
          'Content-Type' => 'text/html',
          'WWW-Authenticate' => 'Basic realm="%s"' % @options[:realm]
        }
        return [ 401, headers, ['<h1>401 Unauthorized</h1>'] ]
      end
  
      def valid?(credentials)
        @authenticator.call(*credentials)
      end
  
    end
  end
end