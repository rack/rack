# frozen_string_literal: true

require 'rack/coders/coder'
module Rack
  module Coders
    class Identity < Coder # :nodoc:
      def encode(obj)
        coder.encode(obj)
      end

      def decode(obj)
        coder.decode(obj)
      end
    end
  end
end
