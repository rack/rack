# frozen_string_literal: true

require_relative 'helper'

separate_testing do
  require_relative '../lib/rack/lint'
  require_relative '../lib/rack/mock_request'
end

describe Rack::CloudfrontHttpsHeader do
  def cloudfront_https_header(app)
    Rack::Lint.new Rack::CloudfrontHttpsHeader.new(app)
  end

  def app
    Rack::Lint.new(Rack::CloudfrontHttpsHeader.new(lambda {|e|
      [200, { "content-type" => "text/plain" }, []]
    }))
  end

  it "does nothing if there is no Cloudfront header" do
    env = Rack::MockRequest.env_for("/", "HTTP_X_FORWARDED_PROTO" => "http")
    app.call env
    env["HTTP_X_FORWARDED_PROTO"].must_equal "http"
  end

  it "copies the Cloudfront header value to X-Forwarded-Proto" do

    env = Rack::MockRequest.env_for("/", "CloudFront-Forwarded-Proto" => "https")
    app.call env
    env["HTTP_X_FORWARDED_PROTO"].must_equal "https"
  end
end
