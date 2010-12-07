require 'mongrel'
require 'stringio'
require 'rack/content_length'
require 'rack/chunked'

module Rack
  module Handler
    class Mongrel < ::Mongrel::HttpHandler
      def self.run(app, options={})
        server = ::Mongrel::HttpServer.new(
          options[:Host]           || '0.0.0.0',
          options[:Port]           || 8080,
          options[:num_processors] || 950,
          options[:throttle]       || 0,
          options[:timeout]        || 60)
        # Acts like Rack::URLMap, utilizing Mongrel's own path finding methods.
        # Use is similar to #run, replacing the app argument with a hash of
        # { path=>app, ... } or an instance of Rack::URLMap.
        if options[:map]
          if app.is_a? Hash
            app.each do |path, appl|
              path = '/'+path unless path[0] == ?/
              server.register(path, Rack::Handler::Mongrel.new(appl))
            end
          elsif app.is_a? URLMap
            app.instance_variable_get(:@mapping).each do |(host, path, appl)|
             next if !host.nil? && !options[:Host].nil? && options[:Host] != host
             path = '/'+path unless path[0] == ?/
             server.register(path, Rack::Handler::Mongrel.new(appl))
            end
          else
            raise ArgumentError, "first argument should be a Hash or URLMap"
          end
        else
          server.register('/', Rack::Handler::Mongrel.new(app))
        end
        yield server  if block_given?
        server.run.join
      end

      def initialize(app)
        @app = app
      end

      def process(request, response)
        env = {}.replace(request.params)
        env.delete CGI_VARIABLE::HTTP_CONTENT_TYPE
        env.delete CGI_VARIABLE::HTTP_CONTENT_LENGTH

        env[CGI_VARIABLE::SCRIPT_NAME] = ""  if env[CGI_VARIABLE::SCRIPT_NAME] == "/"

        rack_input = request.body || StringIO.new('')
        rack_input.set_encoding(Encoding::BINARY) if rack_input.respond_to?(:set_encoding)
        
        env.update({RACK_VARIABLE::VERSION => Rack::VERSION,
                     RACK_VARIABLE::INPUT => rack_input,
                     RACK_VARIABLE::ERRORS => $stderr,

                     RACK_VARIABLE::MULTITHREAD => true,
                     RACK_VARIABLE::MULTIPROCESS => false, # ???
                     RACK_VARIABLE::RUN_ONCE => false,

                     RACK_VARIABLE::URL_SCHEME => Handler.detect_url_scheme
                   })
        env[CGI_VARIABLE::QUERY_STRING] ||= ""

        status, headers, body = @app.call(env)

        begin
          response.status = status.to_i
          response.send_status(nil)

          headers.each { |k, vs|
            vs.split("\n").each { |v|
              response.header[k] = v
            }
          }
          response.send_header

          body.each { |part|
            response.write part
            response.socket.flush
          }
        ensure
          body.close  if body.respond_to? :close
        end
      end
    end
  end
end
