# frozen_string_literal: true

module Rack
  class BodyProxy
    def initialize(body, &block)
      @body = body
      @block = block
      @closed = false
    end

    def respond_to_missing?(method_name, include_all = false)
      super or @body.respond_to?(method_name, include_all)
    end

    def close
      return if @closed
      @closed = true
      begin
        @body.close if @body.respond_to? :close
      ensure
        @block.call
      end
    end

    def closed?
      @closed
    end

    def method_missing(method_name, *args, &block)
      @body.__send__(method_name, *args, &block)
    end
    ruby2_keywords(:method_missing) if respond_to?(:ruby2_keywords, true)
  end
end
