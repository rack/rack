# frozen_string_literal: true

require "thin"
require "thin/server"
require "thin/logging"
require "thin/backends/tcp_server"

module Rack
  module Handler
    class Thin
      def self.run(app, **options)
        environment  = ENV['RACK_ENV'] || 'development'
        default_host = environment == 'development' ? 'localhost' : '0.0.0.0'

        if block_given?
          host = options.delete(:Host) || default_host
          port = options.delete(:Port) || 8080
          args = [host, port, app, options]
          # Thin versions below 0.8.0 do not support additional options
          args.pop if ::Thin::VERSION::MAJOR < 1 && ::Thin::VERSION::MINOR < 8
          server = ::Thin::Server.new(*args)
          yield server
          server.start
        else
          options[:address] = options[:Host] || default_host
          options[:port] = options[:Port] || 8080
          ::Thin::Controllers::Controller.new(options).start
        end
      end

      def self.valid_options
        environment  = ENV['RACK_ENV'] || 'development'
        default_host = environment == 'development' ? 'localhost' : '0.0.0.0'

        {
          "Host=HOST" => "Hostname to listen on (default: #{default_host})",
          "Port=PORT" => "Port to listen on (default: 8080)",
        }
      end
    end
  end
end
