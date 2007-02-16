require 'mongrel'
require 'stringio'

module Rack
  module Handler
    class Mongrel < ::Mongrel::HttpHandler
      def self.run(app, options)
        server = ::Mongrel::HttpServer.new(options[:Host] || '0.0.0.0',
                                           options[:Port] || 8080)
        server.register('/', Rack::Handler::Mongrel.new(app))
        server.run.join
      end
      
      def initialize(app)
        @app = app
      end
      
      def process(request, response)
        env = {}.replace(request.params)
        env.delete "HTTP_CONTENT_TYPE"
        env.delete "HTTP_CONTENT_LENGTH"

        env["SCRIPT_NAME"] = ""  if env["SCRIPT_NAME"] == "/"
        
        env.update({"rack.version" => [0,1],
                     "rack.input" => request.body || StringIO.new(""),
                     "rack.errors" => STDERR,
                     
                     "rack.multithread" => true,
                     "rack.multiprocess" => false, # ???
                     "rack.run_once" => false,
                     
                     "rack.url_scheme" => "http",
                   })
        env["QUERY_STRING"] ||= ""
        env.delete "PATH_INFO"  if env["PATH_INFO"] == ""
        
        status, headers, body = @app.call(env)
        
        response.status = status.to_i
        headers.each { |k, vs|
          vs.each { |v|
            response.header[k] = v
          }
        }
        body.each { |part|
          response.body << part
        }
        response.finished
      end
    end
  end
end
