require 'rack/utils'
require 'rack/middleware'

module Rack
  # Sets the Content-Length header on responses with fixed-length bodies.
  class ContentLength < Rack::Middleware
    include Rack::Utils

    def call(env)
      status, headers, body = super
      headers = HeaderHash.new(headers)

      if !STATUS_WITH_NO_ENTITY_BODY.include?(status.to_i) &&
         !headers['Content-Length'] &&
         !headers['Transfer-Encoding'] &&
         body.respond_to?(:to_ary)

        length = 0
        body.each { |part| length += bytesize(part) }
        headers['Content-Length'] = length.to_s
      end

      [status, headers, body]
    end
  end
end
