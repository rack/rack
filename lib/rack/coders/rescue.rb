# frozen_string_literal: true

require 'rack/coders/coder'
module Rack
  module Coders
    # When there's exception raised, it rescues and returns +nil+.
    class Rescue < Coder # :nodoc:
      def encode(obj)
        coder.encode(obj)
      end

      def decode(obj)
        coder.decode(obj)
      rescue
        nil
      end
    end
  end
end
