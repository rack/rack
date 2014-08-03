require 'webrick'
require 'stringio'
require 'rack/content_length'
require 'rack/handler/environment'

# This monkey patch allows for applications to perform their own chunking
# through WEBrick::HTTPResponse iff rack is set to true.
class WEBrick::HTTPResponse
  attr_accessor :rack

  alias _rack_setup_header setup_header
  def setup_header
    app_chunking = rack && @header['transfer-encoding'] == 'chunked'

    @chunked = app_chunking if app_chunking

    _rack_setup_header

    @chunked = false if app_chunking
  end
end

module Rack
  module Handler
    class WEBrick < ::WEBrick::HTTPServlet::AbstractServlet
      extend Environment

      def self.run(app, options={})
        options[:BindAddress] = options.delete(:Host) || environment
        options[:Port] ||= 8080
        options[:OutputBufferSize] = 5
        @server = ::WEBrick::HTTPServer.new(options)
        @server.mount "/", Rack::Handler::WEBrick, app
        yield @server  if block_given?
        @server.start
      end

      def self.valid_options
        {
          "Host=HOST" => "Hostname to listen on (default: #{environment})",
          "Port=PORT" => "Port to listen on (default: 8080)",
        }
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
        res.rack = true
        env = req.meta_vars
        env.delete_if { |k, v| v.nil? }

        rack_input = StringIO.new(req.body.to_s)
        rack_input.set_encoding(Encoding::BINARY) if rack_input.respond_to?(:set_encoding)

        env.update({"rack.version" => Rack::VERSION,
                     "rack.input" => rack_input,
                     "rack.errors" => $stderr,

                     "rack.multithread" => true,
                     "rack.multiprocess" => false,
                     "rack.run_once" => false,

                     "rack.url_scheme" => ["yes", "on", "1"].include?(env["HTTPS"]) ? "https" : "http",

                     "rack.hijack?" => true,
                     "rack.hijack" => lambda { raise NotImplementedError, "only partial hijack is supported."},
                     "rack.hijack_io" => nil,
                   })

        env["HTTP_VERSION"] ||= env["SERVER_PROTOCOL"]
        env["QUERY_STRING"] ||= ""
        unless env["PATH_INFO"] == ""
          path, n = req.request_uri.path, env["SCRIPT_NAME"].length
          env["PATH_INFO"] = path[n, path.length-n]
        end
        env["REQUEST_PATH"] ||= [env["SCRIPT_NAME"], env["PATH_INFO"]].join

        status, headers, body = @app.call(env)
        begin
          res.status = status.to_i
          headers.each { |k, vs|
            next if k.downcase == "rack.hijack"

            if k.downcase == "set-cookie"
              res.cookies.concat vs.split("\n")
            else
              # Since WEBrick won't accept repeated headers,
              # merge the values per RFC 1945 section 4.2.
              res[k] = vs.split("\n").join(", ")
            end
          }

          io_lambda = headers["rack.hijack"]
          if io_lambda
            rd, wr = IO.pipe
            res.body = rd
            res.chunked = true
            io_lambda.call wr
          else
            body.each { |part|
              res.body << part
            }
          end
        ensure
          body.close  if body.respond_to? :close
        end
      end
    end
  end
end
