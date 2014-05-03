module Rack
  module Handler
    module Environment
      def environment
        if (ENV['RACK_ENV'] || 'development') == 'development'
          'localhost'
        else
          '0.0.0.0'
        end
      end
    end
  end
end
