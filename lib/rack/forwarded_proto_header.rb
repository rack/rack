# frozen_string_literal: true

module Rack

  # Middleware to set the X-Forwarded-Proto header to the value
  # of the CloudFront-Forwarded-Proto header.
  #
  # AWS Cloudfront sets this header for you https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/adding-cloudfront-headers.html#cloudfront-headers-other
  # and it can be used to ensure the scheme matches when comparing
  # request.origin and request.base_url for CSRF checking.
  class ForwardedProtoHeader
    def initialize(app)
      @app = app
    end

    def call(env)
      return @app.call(env) unless env['HTTP_CloudFront-Forwarded-Proto']

      env['HTTP_X_FORWARDED_PROTO'] = env['HTTP_CloudFront-Forwarded-Proto']

      @app.call(env)
    end
  end
end
