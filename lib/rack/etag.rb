require 'digest/md5'

module Rack
  # Automatically sets the ETag header on all String bodies.
  #
  # The ETag header is skipped if ETag or Last-Modified headers
  # are sent or if a sendfile body (responds_to :path) is given
  # (since such cases should be handled by apacha/nginx).
  class ETag
    def initialize(app)
      @app = app
    end

    def call(env)
      status, headers, body = @app.call(env)

      if !body.respond_to?(:to_path) && !headers.key?('ETag') && !headers.key?('Last-Modified')
        digest, body = digest_body(body)
        headers['ETag'] = %("#{digest}")
      end

      [status, headers, body]
    end

    private
      def digest_body(body)
        digest = Digest::MD5.new
        parts = []
        body.each do |part|
          digest << part
          parts << part
        end
        [digest.hexdigest, parts]
      end
  end
end
