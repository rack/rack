# frozen_string_literal: true

require 'rack/coders/coder'
require 'json'
module Rack
  module Coders
    class JSON < Coder # :nodoc:
      def encode(obj)
        ::JSON.dump(coder.encode(obj))
      end

      def decode(str)
        coder.decode(::JSON.parse(str))
      end
    end
  end
end
