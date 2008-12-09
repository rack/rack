require 'rack/mock'
require 'rack/content_length'

context "Rack::ContentLength" do
  specify "sets Content-Length if none is set" do
    app = lambda { |env| [200, {'Content-Type' => 'text/plain'}, "Hello, World!"] }
    response = Rack::ContentLength.new(app).call({})
    response[1]['Content-Length'].should.equal '13'
  end

  specify "set Content-Length if steaming body" do
    app = lambda { |env| [200, {'Content-Type' => 'text/plain'}, ["Hello, ", "World!"]] }
    response = Rack::ContentLength.new(app).call({})
    response[1]['Content-Length'].should.equal '13'
  end

  specify "does not change Content-Length if it is already set" do
    app = lambda { |env| [200, {'Content-Type' => 'text/plain', 'Content-Length' => '1'}, "Hello, World!"] }
    response = Rack::ContentLength.new(app).call({})
    response[1]['Content-Length'].should.equal '1'
  end

  specify "does not set Content-Length if on a 304 request" do
    app = lambda { |env| [304, {'Content-Type' => 'text/plain'}, ""] }
    response = Rack::ContentLength.new(app).call({})
    response[1]['Content-Length'].should.equal nil
  end
end
