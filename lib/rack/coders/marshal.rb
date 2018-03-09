# frozen_string_literal: true

require 'rack/coders/coder'

module Rack
  module Coders
    class Marshal < Coder # :nodoc:
      def encode(obj)
        ::Marshal.dump(coder.encode(obj))
      end

      def decode(str)
        coder.decode(::Marshal.load(str))
      end
    end
  end
end
