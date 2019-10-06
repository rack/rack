# frozen_string_literal: true

module Rack
  class SimpleBodyProxy
    attr_reader :body

    def initialize(body)
      @body = body
    end

    def each(&blk)
      @body.each(&blk)
    end
  end
end
