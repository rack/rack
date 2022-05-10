module Rack
  # Rack::Headers is a Hash subclass that downcases all keys.  It's designed
  # to be used by rack applications that don't implement the Rack 3 SPEC
  # (by using non-lowercase response header keys), automatically handling
  # the downcasing of keys.
  class Headers < Hash
    def self.[](*items)
      if items.length % 2 != 0
        if items.length == 1 && items.first.is_a?(Hash)
          new.merge!(items.first)
        else
          raise ArgumentError, "odd number of arguments for Rack::Headers"
        end
      else
        hash = new
        loop do
          break if items.length == 0
          key = items.shift
          value = items.shift
          hash[key] = value
        end
        hash
      end
    end

    def [](key)
      super(downcase_key(key))
    end

    def []=(key, value)
      super(key.downcase.freeze, value)
    end
    alias store []=
    
    def assoc(key)
      super(downcase_key(key))
    end

    def compare_by_identity
      raise TypeError, "Rack::Headers cannot compare by identity, use regular Hash"
    end

    def delete(key)
      super(downcase_key(key))
    end
    
    def dig(key, *a)
      super(downcase_key(key), *a)
    end

    def fetch(key, *default, &block)
      key = downcase_key(key)
      super
    end
    
    def fetch_values(*a)
      super(*a.map!{|key| downcase_key(key)})
    end

    def has_key?(key)
      super(downcase_key(key))
    end
    alias include? has_key?
    alias key? has_key?
    alias member? has_key?
    
    def invert
      hash = self.class.new
      each{|key, value| hash[value] = key}
      hash
    end
    
    def merge(hash, &block)
      dup.merge!(hash, &block)
    end
    
    def reject(&block)
      hash = dup
      hash.reject!(&block)
      hash
    end
    
    def replace(hash)
      clear
      update(hash)
    end
    
    def select(&block)
      hash = dup
      hash.select!(&block)
      hash
    end
    
    def to_proc
      lambda{|x| self[x]}
    end

    def transform_values(&block)
      dup.transform_values!(&block)
    end

    def update(hash, &block)
      hash.each do |key, value| 
        self[key] = if block_given? && include?(key)
          block.call(key, self[key], value)
        else 
          value
        end
      end
      self
    end
    alias merge! update

    def values_at(*keys)
      keys.map{|key| self[key]}
    end
    
    # :nocov:
    if RUBY_VERSION >= '2.5'
    # :nocov:
      def slice(*a)
        h = self.class.new
        a.each{|k| h[k] = self[k] if has_key?(k)}
        h
      end

      def transform_keys(&block)
        dup.transform_keys!(&block)
      end

      def transform_keys!
        hash = self.class.new
        each do |k, v|
          hash[yield k] = v
        end
        replace(hash)
      end
    end

    # :nocov:
    if RUBY_VERSION >= '3.0'
    # :nocov:
      def except(*a)
        super(*a.map!{|key| downcase_key(key)})
      end
    end

    private

    def downcase_key(key)
      key.is_a?(String) ? key.downcase : key
    end
  end
end
