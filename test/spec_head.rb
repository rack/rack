require 'rack/head'
require 'rack/mock'

describe Rack::Head do

  def test_response(headers = {})
    body = StringIO.new "foo"
    app = lambda do |env|
      [200, {"Content-type" => "test/plain", "Content-length" => "3"}, body]
    end
    request = Rack::MockRequest.env_for("/", headers)
    response = Rack::Head.new(app).call(request)

    return response, body
  end

  should "pass GET, POST, PUT, DELETE, OPTIONS, TRACE requests" do
    %w[GET POST PUT DELETE OPTIONS TRACE].each do |type|
      resp, _ = test_response("REQUEST_METHOD" => type)

      resp[0].should.equal(200)
      resp[1].should.equal({"Content-type" => "test/plain", "Content-length" => "3"})
      resp[2].each { |b| b.should.equal("foo") }
    end
  end

  should "remove body from HEAD requests" do
    resp, _ = test_response("REQUEST_METHOD" => "HEAD")

    resp[0].should.equal(200)
    resp[1].should.equal({"Content-type" => "test/plain", "Content-length" => "3"})
    resp[2].each { |b| flunk "body should be empty" }
  end

  should "close the body when it is removed" do
    resp, body = test_response("REQUEST_METHOD" => "HEAD")
    resp[0].should.equal(200)
    resp[1].should.equal({"Content-type" => "test/plain", "Content-length" => "3"})
    resp[2].each { |b| flunk "body should be empty" }
    body.should.be.closed
  end
end
