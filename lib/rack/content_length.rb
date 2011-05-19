require 'rack/utils'

module Rack
  # Sets the Content-Length header on responses with fixed-length bodies.
  class ContentLength
    include Rack::Utils

    def initialize(app, sendfile=nil)
      @app = app
      @sendfile = sendfile
    end

    def call(env)
      status, headers, body = @app.call(env)
      headers = HeaderHash.new(headers)

      if !STATUS_WITH_NO_ENTITY_BODY.include?(status.to_i) &&
         !headers['Content-Length'] &&
         !headers['Transfer-Encoding'] &&
         !(@sendfile && headers[@sendfile])

        new_body, length = [], 0
        body.each do |part|
          new_body << part
          length += bytesize(part)
        end
        body = new_body
        headers['Content-Length'] = length.to_s
      end

      [status, headers, body]
    end
  end
end
