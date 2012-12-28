require 'rack/head'
require 'rack/mock'

describe Rack::Head do

  @closable_body = Struct.new(:body, :closed) do
    def each
      yield body
    end

    def close
      self.closed = true
    end
    alias closed? closed
  end

  def test_response(headers = {})
    body = @closable_body.new("foo", false)
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
