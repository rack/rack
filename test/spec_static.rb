# frozen_string_literal: true

require_relative 'helper'
require 'zlib'

separate_testing do
  require_relative '../lib/rack/static'
  require_relative '../lib/rack/lint'
  require_relative '../lib/rack/mock_request'
end

class DummyApp
  def call(env)
    [200, { "content-type" => "text/plain" }, ["Hello World"]]
  end
end

describe Rack::Static do
  DOCROOT = File.expand_path(File.dirname(__FILE__)) unless defined? DOCROOT

  def static(app, *args)
    Rack::Lint.new Rack::Static.new(app, *args)
  end

  root = File.expand_path(File.dirname(__FILE__))

  OPTIONS = { urls: ["/cgi"], root: root }
  CASCADE_OPTIONS = { urls: ["/cgi"], root: root, cascade: true }
  STATIC_OPTIONS = { urls: [""], root: "#{root}/static", index: 'index.html' }
  STATIC_URLS_OPTIONS = { urls: ["/static"], root: "#{root}", index: 'index.html' }
  HASH_OPTIONS = { urls: { "/cgi/sekret" => 'cgi/test' }, root: root }
  HASH_ROOT_OPTIONS = { urls: { "/" => "static/foo.html" }, root: root }
  GZIP_OPTIONS = { urls: ["/cgi"], root: root, gzip: true }

  before do
  @request = Rack::MockRequest.new(static(DummyApp.new, OPTIONS))
  @cascade_request = Rack::MockRequest.new(static(DummyApp.new, CASCADE_OPTIONS))
  @static_request = Rack::MockRequest.new(static(DummyApp.new, STATIC_OPTIONS))
  @static_urls_request = Rack::MockRequest.new(static(DummyApp.new, STATIC_URLS_OPTIONS))
  @hash_request = Rack::MockRequest.new(static(DummyApp.new, HASH_OPTIONS))
  @hash_root_request = Rack::MockRequest.new(static(DummyApp.new, HASH_ROOT_OPTIONS))
  @gzip_request = Rack::MockRequest.new(static(DummyApp.new, GZIP_OPTIONS))
  @header_request = Rack::MockRequest.new(static(DummyApp.new, HEADER_OPTIONS))
  end

  it "serves files" do
    res = @request.get("/cgi/test")
    res.must_be :ok?
    res.body.must_match(/ruby/)
  end

  it "does not serve files outside :urls" do
    res = @request.get("/cgi/../#{File.basename(__FILE__)}")
    res.must_be :ok?
    res.body.must_equal "Hello World"
  end

  it "404s if url root is known but it can't find the file" do
    res = @request.get("/cgi/foo")
    res.must_be :not_found?
  end

  it "serves files when using :cascade option" do
    res = @cascade_request.get("/cgi/test")
    res.must_be :ok?
    res.body.must_match(/ruby/)
  end

  it "calls down the chain if if can't find the file when using the :cascade option" do
    res = @cascade_request.get("/cgi/foo")
    res.must_be :ok?
    res.body.must_equal "Hello World"
  end

  it "calls down the chain if url root is not known" do
    res = @request.get("/something/else")
    res.must_be :ok?
    res.body.must_equal "Hello World"
  end

  it "calls index file when requesting root in the given folder" do
    res = @static_request.get("/")
    res.must_be :ok?
    res.body.must_match(/index!/)

    res = @static_request.get("/other/")
    res.must_be :not_found?

    res = @static_request.get("/another/")
    res.must_be :ok?
    res.body.must_match(/another index!/)
  end

  it "does not call index file when requesting folder with unknown prefix" do
    res = @static_urls_request.get("/static/another/")
    res.must_be :ok?
    res.body.must_match(/index!/)

    res = @static_urls_request.get("/something/else/")
    res.must_be :ok?
    res.body.must_equal "Hello World"
  end

  it "doesn't call index file if :index option was omitted" do
    res = @request.get("/")
    res.body.must_equal "Hello World"
  end

  it "serves hidden files" do
    res = @hash_request.get("/cgi/sekret")
    res.must_be :ok?
    res.body.must_match(/ruby/)
  end

  it "calls down the chain if the URI is not specified" do
    res = @hash_request.get("/something/else")
    res.must_be :ok?
    res.body.must_equal "Hello World"
  end

  it "allows the root URI to be configured via hash options" do
    res = @hash_root_request.get("/")
    res.must_be :ok?
    res.body.must_match(/foo.html!/)
  end

  it "serves gzipped files if client accepts gzip encoding and gzip files are present" do
    res = @gzip_request.get("/cgi/test", 'HTTP_ACCEPT_ENCODING' => 'deflate, gzip')
    res.must_be :ok?
    res.headers['content-encoding'].must_equal 'gzip'
    res.headers['content-type'].must_equal 'text/plain'
    Zlib::GzipReader.wrap(StringIO.new(res.body), &:read).must_match(/ruby/)
  end

  it "serves regular files if client accepts gzip encoding and gzip files are not present" do
    res = @gzip_request.get("/cgi/rackup_stub.rb", 'HTTP_ACCEPT_ENCODING' => 'deflate, gzip')
    res.must_be :ok?
    res.headers['content-encoding'].must_be_nil
    res.headers['content-type'].must_equal 'text/x-script.ruby'
    res.body.must_match(/ruby/)
  end

  it "serves regular files if client does not accept gzip encoding" do
    res = @gzip_request.get("/cgi/test")
    res.must_be :ok?
    res.headers['content-encoding'].must_be_nil
    res.headers['content-type'].must_equal 'text/plain'
    res.body.must_match(/ruby/)
  end

  it "returns 304 if gzipped file isn't modified since last serve" do
    path = File.join(DOCROOT, "/cgi/test")
    res = @gzip_request.get("/cgi/test", 'HTTP_IF_MODIFIED_SINCE' => File.mtime(path).httpdate)
    res.status.must_equal 304
    res.body.must_be :empty?
    res.headers['content-encoding'].must_be_nil
    res.headers['content-type'].must_be_nil
  end

  it "return 304 if gzipped file isn't modified since last serve" do
    path = File.join(DOCROOT, "/cgi/test")
    res = @gzip_request.get("/cgi/test", 'HTTP_IF_MODIFIED_SINCE' => File.mtime(path+'.gz').httpdate, 'HTTP_ACCEPT_ENCODING' => 'deflate, gzip')

    res.status.must_equal 304
    res.body.must_be :empty?
  end

  it "supports serving fixed cache-control (legacy option)" do
    opts = OPTIONS.merge(cache_control: 'public')
    request = Rack::MockRequest.new(static(DummyApp.new, opts))
    res = request.get("/cgi/test")
    res.must_be :ok?
    res.headers['cache-control'].must_equal 'public'
  end

  HEADER_OPTIONS = { urls: ["/cgi"], root: root, header_rules: [
    [:all, { 'cache-control' => 'public, max-age=100' }],
    [:fonts, { 'cache-control' => 'public, max-age=200' }],
    [%w(png jpg), { 'cache-control' => 'public, max-age=300' }],
    ['/cgi/assets/folder/', { 'cache-control' => 'public, max-age=400' }],
    ['cgi/assets/javascripts', { 'cache-control' => 'public, max-age=500' }],
    [/\.(css|erb)\z/, { 'cache-control' => 'public, max-age=600' }],
    [false, { 'cache-control' => 'public, max-age=600' }]
  ] }

  it "supports header rule :all" do
    # Headers for all files via :all shortcut
    res = @header_request.get('/cgi/assets/index.html')
    res.must_be :ok?
    res.headers['cache-control'].must_equal 'public, max-age=100'
  end

  it "supports header rule :fonts" do
    # Headers for web fonts via :fonts shortcut
    res = @header_request.get('/cgi/assets/fonts/font.eot')
    res.must_be :ok?
    res.headers['cache-control'].must_equal 'public, max-age=200'
  end

  it "supports file extension header rules provided as an Array" do
    # Headers for file extensions via array
    res = @header_request.get('/cgi/assets/images/image.png')
    res.must_be :ok?
    res.headers['cache-control'].must_equal 'public, max-age=300'
  end

  it "supports folder rules provided as a String" do
    # Headers for files in folder via string
    res = @header_request.get('/cgi/assets/folder/test.js')
    res.must_be :ok?
    res.headers['cache-control'].must_equal 'public, max-age=400'
  end

  it "supports folder header rules provided as a String not starting with a slash" do
    res = @header_request.get('/cgi/assets/javascripts/app.js')
    res.must_be :ok?
    res.headers['cache-control'].must_equal 'public, max-age=500'
  end

  it "supports flexible header rules provided as Regexp" do
    # Flexible Headers via Regexp
    res = @header_request.get('/cgi/assets/stylesheets/app.css')
    res.must_be :ok?
    res.headers['cache-control'].must_equal 'public, max-age=600'
  end

  it "prioritizes header rules over fixed cache-control setting (legacy option)" do
    opts = OPTIONS.merge(
      cache_control: 'public, max-age=24',
      header_rules: [
        [:all, { 'cache-control' => 'public, max-age=42' }]
      ])

    request = Rack::MockRequest.new(static(DummyApp.new, opts))
    res = request.get("/cgi/test")
    res.must_be :ok?
    res.headers['cache-control'].must_equal 'public, max-age=42'
  end

  it "expands the root path upon the middleware initialization" do
    relative_path = STATIC_OPTIONS[:root].sub("#{Dir.pwd}/", '')
    opts = { urls: [""], root: relative_path, index: 'index.html' }
    request = Rack::MockRequest.new(static(DummyApp.new, opts))
    Dir.chdir '..' do
      res = request.get("")
      res.must_be :ok?
      res.body.must_match(/index!/)
    end
  end
end
