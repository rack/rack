require 'fcgi'
require 'socket'
require 'rack/content_length'
require 'rack/rewindable_input'

class FCGI::Stream
  alias _rack_read_without_buffer read

  def read(n, buffer=nil)
    buf = _rack_read_without_buffer n
    buffer.replace(buf.to_s)  if buffer
    buf
  end
end

module Rack
  module Handler
    class FastCGI
      def self.run(app, options={})
        file = options[:File] and STDIN.reopen(UNIXServer.new(file))
        port = options[:Port] and STDIN.reopen(TCPServer.new(port))
        FCGI.each { |request|
          serve request, app
        }
      end

      def self.serve(request, app)
        app = Rack::ContentLength.new(app)

        env = request.env
        env.delete Const::ENV_HTTP_CONTENT_LENGTH

        env[Const::ENV_SCRIPT_NAME] = ""  if env[Const::ENV_SCRIPT_NAME] == "/"
        
        rack_input = RewindableInput.new(request.in)

        env.update({Const::RACK_VERSION => [1,0],
                     Const::RACK_INPUT => rack_input,
                     Const::RACK_ERRORS => request.err,

                     Const::RACK_MULTITHREAD => false,
                     Const::RACK_MULTIPROCESS => true,
                     Const::RACK_RUN_ONCE => false,

                     Const::RACK_URL_SCHEME => ["yes", "on", "1"].include?(env[Const::ENV_HTTPS]) ? "https" : "http"
                   })

        env[Const::ENV_QUERY_STRING] ||= ""
        env[Const::ENV_HTTP_VERSION] ||= env[Const::ENV_SERVER_PROTOCOL]
        env[Const::ENV_REQUEST_PATH] ||= "/"
        env.delete Const::ENV_PATH_INFO  if env[Const::ENV_PATH_INFO] == ""
        env.delete Const::ENV_CONTENT_TYPE  if env[Const::ENV_CONTENT_TYPE] == ""
        env.delete Const::ENV_CONTENT_LENGTH  if env[Const::ENV_CONTENT_LENGTH] == ""

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
