# frozen_string_literal: true

require_relative 'helper'

separate_testing do
  require_relative '../lib/rack/head'
  require_relative '../lib/rack/lint'
  require_relative '../lib/rack/mock_request'
end

describe Rack::Head do

  def test_response(headers = {})
    body = StringIO.new "foo"
    app = lambda do |env|
      [200, { "content-type" => "test/plain", "content-length" => "3" }, body]
    end
    request = Rack::MockRequest.env_for("/", headers)
    response = Rack::Lint.new(Rack::Head.new(app)).call(request)

    return response, body
  end

  it "pass GET, POST, PUT, DELETE, OPTIONS, TRACE requests" do
    %w[GET POST PUT DELETE OPTIONS TRACE].each do |type|
      resp, _ = test_response("REQUEST_METHOD" => type)

      resp[0].must_equal 200
      resp[1].must_equal "content-type" => "test/plain", "content-length" => "3"
      resp[2].to_enum.to_a.must_equal ["foo"]
    end
  end

  it "remove body from HEAD requests" do
    resp, _ = test_response("REQUEST_METHOD" => "HEAD")

    resp[0].must_equal 200
    resp[1].must_equal "content-type" => "test/plain", "content-length" => "3"
    resp[2].to_enum.to_a.must_equal []
  end

  it "close the body when it is removed" do
    resp, body = test_response("REQUEST_METHOD" => "HEAD")
    resp[0].must_equal 200
    resp[1].must_equal "content-type" => "test/plain", "content-length" => "3"
    resp[2].to_enum.to_a.must_equal []
    resp[2].close
    body.must_be :closed?
  end
end
