require 'fcgi'
require 'socket'
require 'rack/content_length'
require 'rack/rewindable_input'

if defined? FCGI::Stream
  class FCGI::Stream
    alias _rack_read_without_buffer read

    def read(n, buffer=nil)
      buf = _rack_read_without_buffer n
      buffer.replace(buf.to_s)  if buffer
      buf
    end
  end
end

module Rack
  module Handler
    class FastCGI
      def self.run(app, options={})
        file = options[:File] and STDIN.reopen(UNIXServer.new(file))
        port = options[:Port] and STDIN.reopen(TCPServer.new(options[:Host], port))
        FCGI.each { |request|
          serve request, app
        }
      end

      def self.serve(request, app)
        env = request.env
        env.delete CGI_VARIABLE::HTTP_CONTENT_LENGTH

        env[CGI_VARIABLE::SCRIPT_NAME] = ""  if env[CGI_VARIABLE::SCRIPT_NAME] == "/"

        rack_input = RewindableInput.new(request.in)

        env.update({RACK_VARIABLE::VERSION => Rack::VERSION,
                     RACK_VARIABLE::INPUT => rack_input,
                     RACK_VARIABLE::ERRORS => request.err,

                     RACK_VARIABLE::MULTITHREAD => false,
                     RACK_VARIABLE::MULTIPROCESS => true,
                     RACK_VARIABLE::RUN_ONCE => false,

                     RACK_VARIABLE::URL_SCHEME => Handler.detect_url_scheme
                   })

        env[CGI_VARIABLE::QUERY_STRING] ||= ""
        env[CGI_VARIABLE::HTTP_VERSION] ||= env[CGI_VARIABLE::SERVER_PROTOCOL]
        env[CGI_VARIABLE::REQUEST_PATH] ||= "/"
        env.delete(CGI_VARIABLE::CONTENT_TYPE)  if env[CGI_VARIABLE::CONTENT_TYPE] == ""
        env.delete(CGI_VARIABLE::CONTENT_LENGTH)  if env[CGI_VARIABLE::CONTENT_LENGTH] == ""

        begin
          status, headers, body = app.call(env)
          begin
            send_headers request.out, status, headers
            send_body request.out, body
          ensure
            body.close  if body.respond_to? :close
          end
        ensure
          rack_input.close
          request.finish
        end
      end

      def self.send_headers(out, status, headers)
        out.print "Status: #{status}\r\n"
        headers.each { |k, vs|
          vs.split("\n").each { |v|
            out.print "#{k}: #{v}\r\n"
          }
        }
        out.print "\r\n"
        out.flush
      end

      def self.send_body(out, body)
        body.each { |part|
          out.print part
          out.flush
        }
      end
    end
  end
end
