require 'test/spec'
require 'stringio'

require 'rack/testrequest'

$-w, w = nil, $-w               # yuck
require 'camping'
require 'rack/adapter/camping'

Camping.goes :CampApp
module CampApp
  module Controllers
    class HW < R('/')
      def get
        "Camping works!"
      end

      def post
        "Data: #{input.foo}"
      end
    end
  end
end
$-w = w

context "Rack::Adapter::Camping" do
  specify "works with GET" do
    status, headers, body = Rack::Adapter::Camping.new(CampApp).call(TestRequest.env({}))

    status.should.be 200
    headers["Content-Type"].should.equal "text/html"

    str = ""; body.each { |part| str << part }
    str.should.equal "Camping works!"
  end

  specify "works with POST" do
    status, headers, body = Rack::Adapter::Camping.new(CampApp).
      call(TestRequest.env({"REQUEST_METHOD" => "POST",
                             "rack.input" => StringIO.new("foo=bar")}))

    status.should.be 200

    str = ""; body.each { |part| str << part }
    str.should.equal "Data: bar"
  end
end
