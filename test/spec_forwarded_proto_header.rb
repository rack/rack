# frozen_string_literal: true

require_relative 'helper'

separate_testing do
  require_relative '../lib/rack/lint'
  require_relative '../lib/rack/mock_request'
end

describe Rack::ForwardedProtoHeader do
  def app
    Rack::Lint.new(Rack::ForwardedProtoHeader.new(lambda {|e|
      [200, {}, []]
    }))
  end

  it "does nothing if there is no Cloudfront header" do
    env = Rack::MockRequest.env_for("/", "HTTP_X_FORWARDED_PROTO" => "http")
    app.call env
    env["HTTP_X_FORWARDED_PROTO"].must_equal "http"
  end

  it "copies the Cloudfront header value to X-Forwarded-Proto" do
    env = Rack::MockRequest.env_for("/", "HTTP_CloudFront-Forwarded-Proto" => "https")
    app.call env
    env["HTTP_X_FORWARDED_PROTO"].must_equal "https"
  end
end
