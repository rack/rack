# frozen_string_literal: true

require 'rack/coders/coder'
module Rack
  module Coders
    class Base64 < Coder # :nodoc:
      def initialize(coder = nil, strict: true)
        super(coder)
        @template_str = strict ? 'm0' : 'm'
      end

      def encode(obj)
        [coder.encode(obj)].pack(@template_str)
      end

      def decode(str)
        coder.decode(str.unpack(@template_str).first)
      end
    end
  end
end
