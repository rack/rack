require 'mongrel'
require 'stringio'

module Rack
  module Handler
    class Mongrel < ::Mongrel::HttpHandler
      def initialize(app)
        @app = app
      end
      
      def process(request, response)
        env = {}.replace(request.params)
        
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
