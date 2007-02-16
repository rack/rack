require 'test/spec'

require 'rack/response'

context "Rack::Response" do
  specify "has sensible default values" do
    response = Rack::Response.new
    status, header, body = response.finish
    status.should.equal 200
    header.should.equal "Content-Type" => "text/html"
    body.each { |part|
      part.should.equal ""
    }

    response = Rack::Response.new
    status, header, body = *response
    status.should.equal 200
    header.should.equal "Content-Type" => "text/html"
    body.each { |part|
      part.should.equal ""
    }
  end

  specify "can be written to" do
    response = Rack::Response.new

    status, header, body = response.finish do
      response.write "foo"
      response.write "bar"
      response.write "baz"
    end
    
    parts = []
    body.each { |part| parts << part }
    
    parts.should.equal ["foo", "bar", "baz"]
  end

  specify "can set and read headers" do
    response = Rack::Response.new
    response["Content-Type"].should.equal "text/html"
    response["Content-Type"] = "text/plain"
    response["Content-Type"].should.equal "text/plain"
  end

  specify "can set cookies" do
    response = Rack::Response.new
    
    response.set_cookie "foo", "bar"
    response["Set-Cookie"].should.equal "foo=bar"
    response.set_cookie "foo2", "bar2"
    response["Set-Cookie"].should.equal ["foo=bar", "foo2=bar2"]
    response.set_cookie "foo3", "bar3"
    response["Set-Cookie"].should.equal ["foo=bar", "foo2=bar2", "foo3=bar3"]
  end

  specify "can delete cookies" do
    response = Rack::Response.new
    response.set_cookie "foo", "bar"
    response.set_cookie "foo2", "bar2"
    response.delete_cookie "foo"
    response["Set-Cookie"].should.equal ["foo2=bar2",
                                  "foo=; expires=Thu, 01 Jan 1970 00:00:00 GMT"]
  end
end
