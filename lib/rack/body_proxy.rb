module Rack
  class BodyProxy
    def initialize(body, &block)
      @body, @block, @closed = body, block, false
    end

    def respond_to?(method_name)
      case method_name
      when :to_ary
        return false
      when String
        return false if /^to_ary$/ =~ method_name
      end
      super or @body.respond_to?(method_name)
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

    # N.B. This method is a special case to address the bug described by #434.
    # We are applying this special case for #each only. Future bugs of this
    # class will be handled by requesting users to patch their ruby
    # implementation, to save adding too many methods in this class.
    def each(*args, &block)
      @body.each(*args, &block)
    end

    def method_missing(*args, &block)
      super if args.first.to_s =~ /^to_ary$/
      @body.__send__(*args, &block)
    end
  end
end
