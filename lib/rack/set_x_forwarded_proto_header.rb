# frozen_string_literal: true

module Rack

  # Middleware to set the X-Forwarded-Proto header to the value
  # of another header.
  #
  # For example, AWS Cloudfront sets a CloudFront-Forwarded-Proto header
  # https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/adding-cloudfront-headers.html#cloudfront-headers-other
  
  # This header can be used to ensure the scheme matches when comparing
  # request.origin and request.base_url for CSRF checking, but Rack
  # expects that value to be in the X_FORWARDED_PROTO header.
  class SetXForwardedProtoHeader
    def initialize(app, vendor_forwarded_header)
      @app = app
      @vendor_forwarded_header = "HTTP_#{vendor_forwarded_header}"
    end

    def call(env)
      return @app.call(env) unless env[@vendor_forwarded_header]
      copy_header_value(env)
      @app.call(env)
    end

    protected

    def copy_header_value(env)
      env["HTTP_X_FORWARDED_PROTO"] = env[@vendor_forwarded_header]
    end
  end
end
