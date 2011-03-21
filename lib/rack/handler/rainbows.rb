require 'rack/handler/unicorn'
require 'rainbows'

module Rack
  module Handler
    class Rainbows < Unicorn
      def self.server
        ::Rainbows
      end
    end
  end
end
