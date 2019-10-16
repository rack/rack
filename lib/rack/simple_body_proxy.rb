# frozen_string_literal: true

module Rack
  class SimpleBodyProxy
    def initialize(body)
      @body = body
    end

    def each(&blk)
      @body.each(&blk)
    end
  end
end
