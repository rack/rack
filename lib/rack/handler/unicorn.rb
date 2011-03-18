require 'unicorn'

module Rack
  module Handler
    class Unicorn
      def self.server
        ::Unicorn
      end

      def self.valid_option?(key, value)
        ::Unicorn::Configurator::DEFAULTS.keys.include?(key) or
        ::Unicorn::Configurator.method_defined? key
      end

      def self.run(app, options = {})
        options[:listeners] ||= begin
          host = options.delete(:Host) || '0.0.0.0'
          port = options.delete(:Port) || 8080
          ["#{host}:#{port}"]
        end

        options.delete_if { |k, v| not valid_option?(k, v) }

        s = server::HttpServer.new app, options
        yield s if block_given?
        s.start.join
      end
    end
  end
end
