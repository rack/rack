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
        @app = Rack::Chunked.new(Rack::ContentLength.new(settings[:app]))
        @log = Object.new
        def @log.info(*args); end
        def @log.error(*args); end
        super(settings)
      end
        
      def process_request(request, input_body, socket)
        env = {}.replace(request)
        env.delete Const::ENV_HTTP_CONTENT_TYPE
        env.delete Const::ENV_HTTP_CONTENT_LENGTH
        env[Const::ENV_REQUEST_PATH], env[Const::ENV_QUERY_STRING] = env[Const::ENV_REQUEST_URI].split('?', 2)
        env[Const::ENV_HTTP_VERSION] ||= env[Const::ENV_SERVER_PROTOCOL]
        env[Const::ENV_PATH_INFO] = env[Const::ENV_REQUEST_PATH]
        env[Const::ENV_QUERY_STRING] ||= ""
        env[Const::ENV_SCRIPT_NAME] = ""

        rack_input = StringIO.new(input_body)
        rack_input.set_encoding(Encoding::BINARY) if rack_input.respond_to?(:set_encoding)

        env.update({Const::RACK_VERSION => [1,0],
                     Const::RACK_INPUT => rack_input,
                     Const::RACK_ERRORS => $stderr,
                     Const::RACK_MULTITHREAD => true,
                     Const::RACK_MULTIPROCESS => true,
                     Const::RACK_RUN_ONCE => false,

                     Const::RACK_URL_SCHEME => ["yes", "on", "1"].include?(env[Const::ENV_HTTPS]) ? "https" : "http"
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
