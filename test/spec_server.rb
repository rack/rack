require 'rack/server'

describe Rack::Server do
  it "overrides :config if :app is passed in" do
    server = Rack::Server.new(:app => "FOO")
    server.app.should == "FOO"
  end
end
