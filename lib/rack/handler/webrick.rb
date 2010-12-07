require 'webrick'
require 'stringio'
require 'rack/content_length'

module Rack
  module Handler
    class WEBrick < ::WEBrick::HTTPServlet::AbstractServlet
      def self.run(app, options={})
        options[:BindAddress] = options.delete(:Host) if options[:Host]
        @server = ::WEBrick::HTTPServer.new(options)
        @server.mount "/", Rack::Handler::WEBrick, app
        yield @server  if block_given?
        @server.start
      end

      def self.shutdown
        @server.shutdown
        @server = nil
      end

      def initialize(server, app)
        super server
        @app = app
      end

      def service(req, res)
        env = req.meta_vars
        env.delete_if { |k, v| v.nil? }

        rack_input = StringIO.new(req.body.to_s)
        rack_input.set_encoding(Encoding::BINARY) if rack_input.respond_to?(:set_encoding)

        env.update({RACK_VARIABLE::VERSION => Rack::VERSION,
                     RACK_VARIABLE::INPUT => rack_input,
                     RACK_VARIABLE::ERRORS => $stderr,

                     RACK_VARIABLE::MULTITHREAD => true,
                     RACK_VARIABLE::MULTIPROCESS => false,
                     RACK_VARIABLE::RUN_ONCE => false,

                     RACK_VARIABLE::URL_SCHEME => Handler.detect_url_scheme
                   })

        env[CGI_VARIABLE::HTTP_VERSION] ||= env[CGI_VARIABLE::SERVER_PROTOCOL]
        env[CGI_VARIABLE::QUERY_STRING] ||= ""
        env[CGI_VARIABLE::REQUEST_PATH] ||= "/"
        unless env[CGI_VARIABLE::PATH_INFO] == ""
          path, n = req.request_uri.path, env[CGI_VARIABLE::SCRIPT_NAME].length
          env[CGI_VARIABLE::PATH_INFO] = path[n, path.length-n]
        end

        status, headers, body = @app.call(env)
        begin
          res.status = status.to_i
          headers.each { |k, vs|
            if k.downcase == "set-cookie"
              res.cookies.concat vs.split("\n")
            else
              # Since WEBrick won't accept repeated headers,
              # merge the values per RFC 1945 section 4.2.
              res[k] = vs.split("\n").join(", ")
            end
          }
          body.each { |part|
            res.body << part
          }
        ensure
          body.close  if body.respond_to? :close
        end
      end
    end
  end
end
