require 'rack/gz_file'
require 'rack/lint'
require 'rack/mock'
require 'zlib'

describe Rack::GzFile do
  DOCROOT = File.expand_path(File.dirname(__FILE__)) unless defined? DOCROOT

  def request
    Rack::MockRequest.new(Rack::Lint.new(Rack::GzFile.new(DOCROOT)))
  end

  should "serve an uncompressed file when gzip is not supported by the server" do
    res = request.get('/cgi/assets/index.html')
    res.body.should.equal "### TestFile ###\n"
    res.headers.should.not.include 'Vary'
    res.headers.should.not.include('Content-Encoding')
    res.headers['Content-Length'].should.equal(
        File.size(DOCROOT + '/cgi/assets/index.html').to_s)
  end

  should "serve an uncompressed file when gzip is not supported by the client" do
    res = request.get('/cgi/assets/compress_me.html')
    res.body.should.equal 'Hello, Rack!'
    res.headers['Vary'].should.equal 'Accept-Encoding'
    res.headers.should.not.include('Content-Encoding')
    res.headers['Content-Length'].should.equal(
        File.size(DOCROOT + '/cgi/assets/compress_me.html').to_s)
  end

  should "serve a compressed file" do
    res = request.get('/cgi/assets/compress_me.html', 
        'HTTP_ACCEPT_ENCODING' => 'gzip')

    gz = Zlib::GzipReader.new(StringIO.new(res.body))
    gz.read.should.equal "Hello, Rack!"
    res.headers['Vary'].should.equal 'Accept-Encoding'
    res.headers['Content-Encoding'].should.equal 'gzip'
    res.headers['Content-Type'].should.equal 'text/html'
    res.headers['Content-Length'].should.equal(
        File.size(DOCROOT + '/cgi/assets/compress_me.html.gz').to_s)
  end
end