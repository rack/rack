module Rack
  # Automatically sets the Content-Length header on all String bodies
  class ContentLength
    STATUS_WITH_NO_ENTITY_BODY = (100..199).to_a << 204 << 304

    def initialize(app)
      @app = app
    end

    def call(env)
      status, headers, body = @app.call(env)

      if !STATUS_WITH_NO_ENTITY_BODY.include?(status) &&
          !headers['Content-Length']

        bytes = 0
        string_body = true

        body.each { |part|
          unless part.kind_of?(String)
            string_body = false
            break
          end

          bytes += (part.respond_to?(:bytesize) ? part.bytesize : part.size)
        }

        headers['Content-Length'] = bytes.to_s if string_body
      end

      [status, headers, body]
    end
  end
end
