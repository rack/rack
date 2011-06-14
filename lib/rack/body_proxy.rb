module Rack
  class BodyProxy
    def initialize(body, &block)
      @body, @block, @closed = body, block, false
    end

    def respond_to?(*args)
      super or @body.respond_to?(*args)
    end

    def close
      raise IOError, "closed stream" if @closed
      begin
        @body.close if @body.respond_to? :close
      ensure
        @block.call
        @closed = true
      end
    end

    def closed?
      @closed
    end

    def method_missing(*args, &block)
      @body.__send__(*args, &block)
    end
  end
end
