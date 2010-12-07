require 'lsapi'
require 'rack/content_length'
require 'rack/rewindable_input'

module Rack
  module Handler
    class LSWS
      def self.run(app, options=nil)
        while LSAPI.accept != nil
          serve app
        end
      end
      def self.serve(app)
        env = ENV.to_hash
        env.delete CGI_VARIABLE::HTTP_CONTENT_LENGTH
        env[CGI_VARIABLE::SCRIPT_NAME] = "" if env[CGI_VARIABLE::SCRIPT_NAME] == "/"

        rack_input = RewindableInput.new($stdin.read.to_s)

        env.update(
          RACK_VARIABLE::VERSION => Rack::VERSION,
          RACK_VARIABLE::INPUT => rack_input,
          RACK_VARIABLE::ERRORS => $stderr,
          RACK_VARIABLE::MULTITHREAD => false,
          RACK_VARIABLE::MULTIPROCESS => true,
          RACK_VARIABLE::RUN_ONCE => false,
          RACK_VARIABLE::URL_SCHEME => Handler.detect_url_scheme
        )

        env[CGI_VARIABLE::QUERY_STRING] ||= ""
        env[CGI_VARIABLE::HTTP_VERSION] ||= env[CGI_VARIABLE::SERVER_PROTOCOL]
        env[CGI_VARIABLE::REQUEST_PATH] ||= "/"
        status, headers, body = app.call(env)
        begin
          send_headers status, headers
          send_body body
        ensure
          body.close if body.respond_to? :close
        end
      ensure
        rack_input.close
      end
      def self.send_headers(status, headers)
        print "Status: #{status}\r\n"
        headers.each { |k, vs|
          vs.split("\n").each { |v|
            print "#{k}: #{v}\r\n"
          }
        }
        print "\r\n"
        STDOUT.flush
      end
      def self.send_body(body)
        body.each { |part|
          print part
          STDOUT.flush
        }
      end
    end
  end
end
