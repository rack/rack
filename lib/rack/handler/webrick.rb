require 'webrick'
require 'stringio'
require 'rack/content_length'

module Rack
  module Handler
    class WEBrick < ::WEBrick::HTTPServlet::AbstractServlet
      def self.run(app, options={})
        options[:BindAddress] = options.delete(:Host) if options[:Host]
        server = ::WEBrick::HTTPServer.new(options)
        server.mount "/", Rack::Handler::WEBrick, app
        trap(:INT) { server.shutdown }
        yield server  if block_given?
        server.start
      end

      def initialize(server, app)
        super server
        @app = Rack::ContentLength.new(app)
      end

      def service(req, res)
        env = req.meta_vars
        env.delete_if { |k, v| v.nil? }

        rack_input = StringIO.new(req.body.to_s)
        rack_input.set_encoding(Encoding::BINARY) if rack_input.respond_to?(:set_encoding)

        env.update({Const::RACK_VERSION => [1,0],
                     Const::RACK_INPUT => rack_input,
                     Const::RACK_ERRORS => $stderr,

                     Const::RACK_MULTITHREAD => true,
                     Const::RACK_MULTIPROCESS => false,
                     Const::RACK_RUN_ONCE => false,

                     Const::RACK_URL_SCHEME => ["yes", "on", "1"].include?(ENV[Const::ENV_HTTPS]) ? "https" : "http"
                   })

        env[Const::ENV_HTTP_VERSION] ||= env[Const::ENV_SERVER_PROTOCOL]
        env[Const::ENV_QUERY_STRING] ||= ""
        env[Const::ENV_REQUEST_PATH] ||= "/"
        if env[Const::ENV_PATH_INFO] == ""
          env.delete Const::ENV_PATH_INFO
        else
          path, n = req.request_uri.path, env[Const::ENV_SCRIPT_NAME].length
          env[Const::ENV_PATH_INFO] = path[n, path.length-n]
        end

        status, headers, body = @app.call(env)
        begin
          res.status = status.to_i
          headers.each { |k, vs|
            if k.downcase == "set-cookie"
              res.cookies.concat vs.split("\n")
            else
              vs.split("\n").each { |v|
                res[k] = v
              }
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
