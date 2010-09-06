require 'digest/md5'

module Rack
  # Automatically sets the ETag header on all String bodies.
  #
  # The ETag header is skipped if ETag or Last-Modified headers are sent or if
  # a sendfile body (body.responds_to :to_path) is given (since such cases
  # should be handled by apache/nginx).
  class ETag
    DEFAULT_CACHE_CONTROL = "max-age=0, private, must-revalidate".freeze

    def initialize(app, cache_control = DEFAULT_CACHE_CONTROL)
      @app = app
      @cache_control = cache_control
    end

    def call(env)
      status, headers, body = @app.call(env)

      if etag_status?(status) && !body.respond_to?(:to_path) && !http_caching?(headers)
        digest, body = digest_body(body)
        headers['ETag'] = %("#{digest}")
        headers['Cache-Control'] = @cache_control unless headers['Cache-Control']
      end

      [status, headers, body]
    end

    private

      def etag_status?(status)
        status == 200 || status == 201
      end

      def http_caching?(headers)
        headers.key?('ETag') || headers.key?('Last-Modified')
      end

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
