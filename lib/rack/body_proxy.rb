module Rack
  class BodyProxy < defined?(BasicObject) ? BasicObject : Object
    def initialize(body, &block)
      @body, @block = body, block
    end

    def respond_to?(*args)
      super or @body.respond_to?(*args)
    end

    def close
      @body.close if @body.respond_to? :close
    ensure
      @block.call
    end

    def method_missing(*args, &block)
      @body.__send__(*args, &block)
    end
  end
end
