require "thin"
require "rack/content_length"
require "rack/chunked"
require "rack/handler/environment"

module Rack
  module Handler
    class Thin
      extend Environment

      def self.run(app, options={})
        @app = app
        @options = options

        yield server if block_given?

        server.start
      end

      def self.valid_options
        {
          "Host=HOST" => "Hostname to listen on (default: #{environment})",
          "Port=PORT" => "Port to listen on (default: 8080)",
        }
      end

      private
      def self.prepare_args
        host = @options.delete(:Host) || environment
        port = @options.delete(:Port) || 8080
        args = [host, port, @app, @options]

        args.pop if has_not_support_for_additional_options?
        args
      end

      def self.server
        @server ||= ::Thin::Server.new(*prepare_args)
      end

      def self.has_not_support_for_additional_options?
        # Thin versions below 0.8.0 do not support additional options
        ::Thin::VERSION::MAJOR < 1 && ::Thin::VERSION::MINOR < 8
      end
    end
  end
end
