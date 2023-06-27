# frozen_string_literal: true

require_relative 'helper'


describe Rack::SetXForwardedProtoHeader do
  response = lambda {|e| [200, {}, []]  }

  it "leaves the value of X_FORWARDED_PROTO intact if there is no vendor header passed in the request" do
    vendor_forwarded_header = "not passed in the request"
    env = Rack::MockRequest.env_for("/", "HTTP_X_FORWARDED_PROTO" => "http")

    Rack::Lint.new(Rack::SetXForwardedProtoHeader.new(response, vendor_forwarded_header)).call env

    env["HTTP_X_FORWARDED_PROTO"].must_equal "http"
  end

  it "returns early when there is no vendor header passed in the request" do
    vendor_forwarded_header = "not passed in the request"
    env = Rack::MockRequest.env_for("/", "FOO" => "bar")

    header_middleware = Rack::SetXForwardedProtoHeader.new(response, vendor_forwarded_header)
    # Patch to ensure we return early and do not call `copy_header_value`
    def header_middleware.copy_header_value
      raise NoMethodError, "should never be called when vendor_forwarded_header is not in the request"
    end

    Rack::Lint.new(header_middleware).call env

    env["FOO"].must_equal "bar"
  end


  it "copies the value of the header to X-Forwarded-Proto" do
    env = Rack::MockRequest.env_for("/", "HTTP_VENDOR_FORWARDED_PROTO_HEADER" => "https")

    Rack::Lint.new(Rack::SetXForwardedProtoHeader.new(response, "Vendor-Forwarded-Proto-Header")).call env

    env["HTTP_X_FORWARDED_PROTO"].must_equal "https"
  end

  it "copies the value of the header to X-Forwarded-Proto overwriting an existing X-Forwarded-Proto" do
    env = Rack::MockRequest.env_for("/", "HTTP_VENDOR_FORWARDED_PROTO_HEADER" => "https", "HTTP_X_FORWARDED_PROTO" => "http")

    Rack::Lint.new(Rack::SetXForwardedProtoHeader.new(response, "Vendor-Forwarded-Proto-Header")).call env

    env["HTTP_X_FORWARDED_PROTO"].must_equal "https"
  end

  
end
