require 'test/spec'

require 'rack'
require 'rack/mock'

context "Rack::Builder" do
  specify "chains apps by default" do
    app = Rack::Builder.new do
      use Rack::ShowExceptions
      run lambda { |env| raise "bzzzt" }
    end.to_app

    Rack::MockRequest.new(app).get("/").should.be.server_error
    Rack::MockRequest.new(app).get("/").should.be.server_error
    Rack::MockRequest.new(app).get("/").should.be.server_error
  end

  specify "has implicit #to_app" do
    app = Rack::Builder.new do
      use Rack::ShowExceptions
      run lambda { |env| raise "bzzzt" }
    end

    Rack::MockRequest.new(app).get("/").should.be.server_error
    Rack::MockRequest.new(app).get("/").should.be.server_error
    Rack::MockRequest.new(app).get("/").should.be.server_error
  end
end
