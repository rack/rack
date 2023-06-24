# frozen_string_literal: true

module Rack

  # Middleware to set the X-Forwarded-Proto header to the value
  # of another header.
  #
  # This header can be used to ensure the scheme matches when comparing
  # request.origin and request.base_url for CSRF checking, but Rack
  # expects that value to be in the X_FORWARDED_PROTO header.
  #
  # For example, AWS Cloudfront sets a CloudFront-Forwarded-Proto header
  # https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/adding-cloudfront-headers.html#cloudfront-headers-other
  #
  # Example Rails usage with AWS Cloudfront:
  # In this AWS example, add 
  #`config.middleware.use Rack::SetXForwardedProtoHeader, 'CloudFront-Forwarded-Proto'`
  # to your application.rb file
  
  class SetXForwardedProtoHeader
    def initialize(app, vendor_forwarded_header)
      @app = app
      @vendor_forwarded_header = standard_header vendor_forwarded_header
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

    def standard_header(header)
      # Rack expects to see UPPER_UNDERSCORED_HEADERS, never SnakeCased-Dashed-Headers
      upper_underscored = header.upcase.gsub "-", "_"
      return "HTTP_#{upper_underscored}"
    end
  end
end
