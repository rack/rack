require 'test/spec'

require 'rack/file'
require 'rack/lint'

require 'rack/testrequest'

context "Rack::File" do
  DOCROOT = File.expand_path(File.dirname(__FILE__))

  specify "serves files" do
    file = Rack::Lint.new(Rack::File.new(DOCROOT))

    status, headers, body = file.call(TestRequest.env("PATH_INFO" => "/cgi/test"))
    status.to_i.should.equal 200
    body.each { |part|
      part.should.match(/ruby/)
      break
    }
  end

  specify "does not allow directory traversal" do
    file = Rack::Lint.new(Rack::File.new(DOCROOT))
    status, _, _ = file.call(TestRequest.env("PATH_INFO" => "/cgi/../test"))
    status.to_i.should.equal 403
  end

  specify "404s if it can't find the file" do
    file = Rack::Lint.new(Rack::File.new(DOCROOT))
    status, _, _ = file.call(TestRequest.env("PATH_INFO" => "/cgi/blubb"))
    status.to_i.should.equal 404
  end
end
