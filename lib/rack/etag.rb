# frozen_string_literal: true

require_relative '../rack'
require 'digest/sha2'

module Rack
  # Automatically sets the ETag header on all String bodies.
  #
  # The ETag header is skipped if ETag or Last-Modified headers are sent or if
  # a sendfile body (body.responds_to :to_path) is given (since such cases
  # should be handled by apache/nginx).
  #
  # On initialization, you can pass keywords:
  # no_cache_control :: a Cache-Control directive to use when ETag is absent (default: nil)
  # cache_control :: a Cache-Control directive when ETag is present
  #                  (default: "max-age=0, private, must-revalidate").
  # skip_etag_if_no_cache :: Whether to skip setting the ETag if the Cache-Control header already
  #                          includes no-cache (default: true).  Setting this to false causes such
  #                          responses to be bufferred in order to generate the ETag, which
  #                          can cause problems with streaming responses.
  class ETag
    ETAG_STRING = Rack::ETAG
    DEFAULT_CACHE_CONTROL = "max-age=0, private, must-revalidate"

    def initialize(app, no_cache_control_arg = nil, cache_control_arg = DEFAULT_CACHE_CONTROL,
                   no_cache_control: no_cache_control_arg, cache_control: cache_control_arg,
                   skip_etag_if_no_cache: true)
      @app = app
      @cache_control = cache_control
      @no_cache_control = no_cache_control
      @skip_etag_if_no_cache = skip_etag_if_no_cache
    end

    def call(env)
      status, headers, body = @app.call(env)
      headers = Utils::HeaderHash[headers]

      if etag_status?(status) && etag_body?(body) && !skip_caching?(headers)
        original_body = body
        digest, new_body = digest_body(body)
        body = Rack::BodyProxy.new(new_body) do
          original_body.close if original_body.respond_to?(:close)
        end
        headers[ETAG_STRING] = %(W/"#{digest}") if digest
      end

      unless headers[CACHE_CONTROL]
        if digest
          headers[CACHE_CONTROL] = @cache_control if @cache_control
        else
          headers[CACHE_CONTROL] = @no_cache_control if @no_cache_control
        end
      end

      [status, headers, body]
    end

    private

      def etag_status?(status)
        status == 200 || status == 201
      end

      def etag_body?(body)
        !body.respond_to?(:to_path)
      end

      def skip_caching?(headers)
        if @skip_etag_if_no_cache && (headers[CACHE_CONTROL] && headers[CACHE_CONTROL].include?('no-cache'))
          return true
        end
        headers.key?(ETAG_STRING) || headers.key?('Last-Modified')
      end

      def digest_body(body)
        parts = []
        digest = nil

        body.each do |part|
          parts << part
          (digest ||= Digest::SHA256.new) << part unless part.empty?
        end

        [digest && digest.hexdigest.byteslice(0, 32), parts]
      end
  end
end
