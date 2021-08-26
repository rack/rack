# frozen_string_literal: true

require_relative 'helper'

describe Rack::MethodOverride do
  def app
    Rack::Lint.new(Rack::MethodOverride.new(lambda {|e|
      [200, { "Content-Type" => "text/plain" }, []]
    }))
  end

  it "not affect GET requests" do
    env = Rack::MockRequest.env_for("/?_method=delete", method: "GET")
    app.call env

    env["REQUEST_METHOD"].must_equal "GET"
  end

  it "sets rack.errors for invalid UTF8 _method values" do
    errors = StringIO.new
    env = Rack::MockRequest.env_for("/",
      :method => "POST",
      :input => "_method=\xBF".b,
      Rack::RACK_ERRORS => errors)

    app.call env

    errors.rewind
    errors.read.must_equal "Invalid string for method\n"
    env["REQUEST_METHOD"].must_equal "POST"
  end

  it "modify REQUEST_METHOD for POST requests when _method parameter is set" do
    env = Rack::MockRequest.env_for("/", method: "POST", input: "_method=put")
    app.call env

    env["REQUEST_METHOD"].must_equal "PUT"
  end

  it "modify REQUEST_METHOD for POST requests when X-HTTP-Method-Override is set" do
    env = Rack::MockRequest.env_for("/",
            :method => "POST",
            "HTTP_X_HTTP_METHOD_OVERRIDE" => "PATCH"
          )
    app.call env

    env["REQUEST_METHOD"].must_equal "PATCH"
  end

  it "not modify REQUEST_METHOD if the method is unknown" do
    env = Rack::MockRequest.env_for("/", method: "POST", input: "_method=foo")
    app.call env

    env["REQUEST_METHOD"].must_equal "POST"
  end

  it "not modify REQUEST_METHOD when _method is nil" do
    env = Rack::MockRequest.env_for("/", method: "POST", input: "foo=bar")
    app.call env

    env["REQUEST_METHOD"].must_equal "POST"
  end

  it "store the original REQUEST_METHOD prior to overriding" do
    env = Rack::MockRequest.env_for("/",
            method: "POST",
            input: "_method=options")
    app.call env

    env["rack.methodoverride.original_method"].must_equal "POST"
  end

  it "not modify REQUEST_METHOD when given invalid multipart form data" do
    input = <<EOF
--AaB03x\r
content-disposition: form-data; name="huge"; filename="huge"\r
EOF
    env = Rack::MockRequest.env_for("/",
                      "CONTENT_TYPE" => "multipart/form-data, boundary=AaB03x",
                      "CONTENT_LENGTH" => input.size.to_s,
                      :method => "POST", :input => input)
    app.call env

    env["REQUEST_METHOD"].must_equal "POST"
  end

  it "writes error to RACK_ERRORS when given invalid multipart form data" do
    input = <<EOF
--AaB03x\r
content-disposition: form-data; name="huge"; filename="huge"\r
EOF
    env = Rack::MockRequest.env_for("/",
                      "CONTENT_TYPE" => "multipart/form-data, boundary=AaB03x",
                      "CONTENT_LENGTH" => input.size.to_s,
                      Rack::RACK_ERRORS => StringIO.new,
                      :method => "POST", :input => input)
    Rack::MethodOverride.new(proc { [200, { "Content-Type" => "text/plain" }, []] }).call env

    env[Rack::RACK_ERRORS].rewind
    env[Rack::RACK_ERRORS].read.must_match /Bad request content body/
  end

  it "not modify REQUEST_METHOD for POST requests when the params are unparseable" do
    env = Rack::MockRequest.env_for("/", method: "POST", input: "(%bad-params%)")
    app.call env

    env["REQUEST_METHOD"].must_equal "POST"
  end
end
