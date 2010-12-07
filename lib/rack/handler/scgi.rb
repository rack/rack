require 'scgi'
require 'stringio'
require 'rack/content_length'
require 'rack/chunked'

module Rack
  module Handler
    class SCGI < ::SCGI::Processor
      attr_accessor :app

      def self.run(app, options=nil)
        new(options.merge(:app=>app,
                          :host=>options[:Host],
                          :port=>options[:Port],
                          :socket=>options[:Socket])).listen
      end

      def initialize(settings = {})
        @app = settings[:app]
        super(settings)
      end

      def process_request(request, input_body, socket)
        env = {}.replace(request)
        env.delete CGI_VARIABLE::HTTP_CONTENT_TYPE
        env.delete CGI_VARIABLE::HTTP_CONTENT_LENGTH
        env[CGI_VARIABLE::REQUEST_PATH], env[CGI_VARIABLE::QUERY_STRING] = env[CGI_VARIABLE::REQUEST_URI].split('?', 2)
        env[CGI_VARIABLE::HTTP_VERSION] ||= env[CGI_VARIABLE::SERVER_PROTOCOL]
        env[CGI_VARIABLE::PATH_INFO] = env[CGI_VARIABLE::REQUEST_PATH]
        env[CGI_VARIABLE::QUERY_STRING] ||= ""
        env[CGI_VARIABLE::SCRIPT_NAME] = ""

        rack_input = StringIO.new(input_body)
        rack_input.set_encoding(Encoding::BINARY) if rack_input.respond_to?(:set_encoding)

        env.update({RACK_VARIABLE::VERSION => Rack::VERSION,
                     RACK_VARIABLE::INPUT => rack_input,
                     RACK_VARIABLE::ERRORS => $stderr,
                     RACK_VARIABLE::MULTITHREAD => true,
                     RACK_VARIABLE::MULTIPROCESS => true,
                     RACK_VARIABLE::RUN_ONCE => false,

                     RACK_VARIABLE::URL_SCHEME => Handler.detect_url_scheme
                   })
        status, headers, body = app.call(env)
        begin
          socket.write("Status: #{status}\r\n")
          headers.each do |k, vs|
            vs.split("\n").each { |v| socket.write("#{k}: #{v}\r\n")}
          end
          socket.write("\r\n")
          body.each {|s| socket.write(s)}
        ensure
          body.close if body.respond_to? :close
        end
      end
    end
  end
end
