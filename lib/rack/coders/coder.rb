# frozen_string_literal: true

module Rack
  module Coders
    # The abstract class of coder, must implement #encode and #decode.
    # It's designed with decorator pattern, which makes it more flexible,
    # and can be wrapped infinitely using Ruby instantiation.
    #
    # To implement a custom coder decorator, inherit from Coders::Coder, and use
    # +coder.encode+, +coder.decode+ to get results from base coder:
    #
    #    class Reverse < Coders::Coder
    #       def encode(str); coder.encode(str).reverse; end
    #       def decode(str); coder.decode(str.reverse); end
    #    end
    #    coder = Reverse.new(Coder::Base64.new)
    #
    # If you want to customize options, be sure to call super:
    #
    #     class MyCoder < Coders::Coder
    #       def initialize(gueset_coder = nil, options = {})
    #         super(guest_coder)
    #         @options = options
    #       end
    #     end
    #
    class Coder
      attr_reader :coder

      # Can optionally pass a base coder which is going to be decorated.
      def initialize(coder = nil)
        @coder = coder || Null.new
      end

      def encode(_obj)
        raise NotImplementedError
      end

      # It decodes +_obj+, returning decoded data.
      def decode(_obj)
        raise NotImplementedError
      end
    end

    class Null # :nodoc:
      def encode(obj)
        obj
      end

      def decode(obj)
        obj
      end
    end
  end
end
