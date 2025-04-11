# frozen_string_literal: false

require_relative 'helper'
require 'yaml'
require_relative 'psych_fix'

separate_testing do
  require_relative '../lib/rack/mock_request'
  require_relative '../lib/rack/lint'
  require_relative '../lib/rack/request'
  require_relative '../lib/rack/body_proxy'
end

app = Rack::Lint.new(lambda { |env|
  req = Rack::Request.new(env)

  if input = env["rack.input"]
    env["mock.postdata"] = input.read
  end

  if req.GET["error"]
    env["rack.errors"].puts req.GET["error"]
    env["rack.errors"].flush
  end

  body = req.head? ? "" : env.to_yaml
  response = Rack::Response.new(
    body,
    req.GET["status"] || 200,
    "content-type" => "text/yaml"
  )
  response.set_cookie("session_test", { value: "session_test", domain: "test.com", path: "/" })
  response.set_cookie("secure_test", { value: "secure_test", domain: "test.com",  path: "/", secure: true })
  response.set_cookie("persistent_test", { value: "persistent_test", max_age: 15552000, path: "/" })
  response.set_cookie("persistent_with_expires_test", { value: "persistent_with_expires_test", expires: Time.httpdate("Thu, 31 Oct 2021 07:28:00 GMT"), path: "/" })
  response.set_cookie("expires_and_max-age_test", { value: "expires_and_max-age_test", expires: Time.now + 15552000 * 2, max_age: 15552000, path: "/" })
  response.finish
})

describe Rack::MockRequest do
  it "doesn't warn when POST is given an unfrozen constant string" do
    Warning[:deprecated] = true
    capture_warnings(Warning) do |warnings|
      env = Rack::MockRequest.env_for("/foo", method: :post, input: "test")
      warnings.must_be :empty?
      env["REQUEST_METHOD"].must_equal "POST"
      env["QUERY_STRING"].must_equal ""
      env["PATH_INFO"].must_equal "/foo"
      env["rack.input"].string.must_equal "test"
    end
    Warning[:deprecated] = false
  end
end
