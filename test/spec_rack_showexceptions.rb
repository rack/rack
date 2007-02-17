require 'test/spec'

require 'rack/showexceptions'
require 'rack/testrequest'

context "Rack::ShowExceptions" do
  specify "catches exceptions" do
    status = headers = body = nil
    lambda {
      status, headers, body = Rack::ShowExceptions.new(lambda { |env|
                                                         raise RuntimeError
                                                       }).
                                                       call(TestRequest.env({}))
    }.should.not.raise
    status.should.equal 500

    str = ""; body.each { |part| str << part }
    str.should =~ /RuntimeError/
    str.should =~ /ShowExceptions/
  end
end
