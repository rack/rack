require 'rack/request'
require 'rack/utils'

module Rack
  class Response
    def initialize
      @status = 200
      @header = Utils::HeaderHash.new({"Content-Type" => "text/html"})
      @body = []

      @writer = lambda { |x| @body << x }
    end

    attr_reader :status, :header, :body

    def [](key)
      header[key]
    end

    def []=(key, value)
      header[key] = value
    end

    def set_cookie(key, value)
      case value
      when Hash
        domain  = "; domain="  + value[:domain]    if value[:domain]
        path    = "; path="    + value[:path]      if value[:path]
        expires = "; expires=" + value[:expires].clone.gmtime.
          strftime("%a, %d %b %Y %H:%M:%S GMT")    if value[:expires]
        value = value[:value]
      end
      value = [value]  unless Array === value
      cookie = Utils.escape(key) + "=" +
        value.map { |v| Utils.escape v }.join("&") +
        "#{domain}#{path}#{expires}"

      case self["Set-Cookie"]
      when Array
        self["Set-Cookie"] << cookie
      when String
        self["Set-Cookie"] = [self["Set-Cookie"], cookie]
      when nil
        self["Set-Cookie"] = cookie
      end
    end

    def delete_cookie(key, value={})
      unless Array === self["Set-Cookie"]
        self["Set-Cookie"] = [self["Set-Cookie"]]
      end

      self["Set-Cookie"].reject! { |cookie|
        cookie =~ /\A#{Utils.escape(key)}=/
      }

      set_cookie(key,
                 {:value => '', :path => nil, :domain => nil,
                   :expires => Time.at(0) }.merge(value))
    end


    def finish(&block)
      block.call  if block
      [status.to_i, header.to_hash, self]
    end
    alias to_a finish           # For *response

    def each(&block)
      @writer = block
      @body.each(&block)
    end

    def write(str)
      @writer.call str
    end
  end
end
