# frozen_string_literal: true

require 'rack/coders/coder'
require 'zlib'
module Rack
  module Coders
    class Zip < Coder # :nodoc:
      def encode(str)
        ::Zlib::Deflate.deflate(coder.encode(str))
      end

      def decode(str)
        coder.decode(::Zlib::Inflate.inflate(str))
      end
    end
  end
end
