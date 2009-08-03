require 'rack/content_length'

module Rack
  module Handler
    class CGI
      def self.run(app, options=nil)
        serve app
      end

      def self.serve(app)
        app = ContentLength.new(app)

        env = ENV.to_hash
        env.delete Const::ENV_HTTP_CONTENT_LENGTH

        env[Const::ENV_SCRIPT_NAME] = ""  if env[Const::ENV_SCRIPT_NAME] == "/"

        env.update({Const::RACK_VERSION => [1,0],
                     Const::RACK_INPUT => $stdin,
                     Const::RACK_ERRORS => $stderr,

                     Const::RACK_MULTITHREAD => false,
                     Const::RACK_MULTIPROCESS => true,
                     Const::RACK_RUN_ONCE => true,

                     Const::RACK_URL_SCHEME => ["yes", "on", "1"].include?(ENV[Const::ENV_HTTPS]) ? "https" : "http"
                   })

        env[Const::ENV_QUERY_STRING] ||= ""
        env[Const::ENV_HTTP_VERSION] ||= env[Const::ENV_SERVER_PROTOCOL]
        env[Const::ENV_REQUEST_PATH] ||= "/"

        status, headers, body = app.call(env)
        begin
          send_headers status, headers
          send_body body
        ensure
          body.close  if body.respond_to? :close
        end
      end

      def self.send_headers(status, headers)
        STDOUT.print "Status: #{status}\r\n"
        headers.each { |k, vs|
          vs.split("\n").each { |v|
            STDOUT.print "#{k}: #{v}\r\n"
          }
        }
        STDOUT.print "\r\n"
        STDOUT.flush
      end

      def self.send_body(body)
        body.each { |part|
          STDOUT.print part
          STDOUT.flush
        }
      end
    end
  end
end
