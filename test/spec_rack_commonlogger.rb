require 'test/spec'
require 'stringio'

require 'rack/commonlogger'
require 'rack/lobster'
require 'rack/testrequest'

context "Rack::CommonLogger" do
  specify "should log to rack.errors by default" do
    log = StringIO.new
    _,_, b = Rack::CommonLogger.new(lambda { |env|
                                      [200,
                                       {"Content-Type" => "text/html"},
                                       ["foo"]]
                                    }).
      call(TestRequest.env({'rack.errors' => log}))
    b.each { }

    log.string.should =~ /GET /
    log.string.should =~ / 200 / # status
    log.string.should =~ / 3 / # length
  end

  specify "should log to anything with <<" do
    log = ""
    _,_, b = Rack::CommonLogger.new(lambda { |env|
                                      [200,
                                       {"Content-Type" => "text/html"},
                                       ["foo"]]
                                    },
                                    log).call(TestRequest.env({}))
    b.each { }

    log.should =~ /GET /
    log.should =~ / 200 / # status
    log.should =~ / 3 / # length
  end
end
