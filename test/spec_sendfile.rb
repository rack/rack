# frozen_string_literal: true

require_relative 'helper'
require 'fileutils'
require 'tmpdir'

separate_testing do
  require_relative '../lib/rack/sendfile'
  require_relative '../lib/rack/lint'
  require_relative '../lib/rack/mock_request'
end

describe Rack::Sendfile do
  def sendfile_body(filename = "rack_sendfile")
    FileUtils.touch File.join(Dir.tmpdir,  filename)
    res = ['Hello World']
    res.define_singleton_method(:to_path) { File.join(Dir.tmpdir,  filename) }
    res
  end

  def simple_app(body = sendfile_body)
    lambda { |env| [200, { 'content-type' => 'text/plain' }, body] }
  end

  def sendfile_app(body, mappings = [])
    Rack::Lint.new Rack::Sendfile.new(simple_app(body), nil, mappings)
  end

  def request(headers = {}, body = sendfile_body, mappings = [])
    yield Rack::MockRequest.new(sendfile_app(body, mappings)).get('/', headers)
  end

  def open_file(path)
    Class.new(File) do
      unless method_defined?(:to_path)
        alias :to_path :path
      end
    end.open(path, 'wb+')
  end

  it "does nothing when no x-sendfile-type header present" do
    request do |response|
      response.must_be :ok?
      response.body.must_equal 'Hello World'
      response.headers.wont_include 'x-sendfile'
    end
  end

  it "does nothing and logs to rack.errors when incorrect x-sendfile-type header present" do
    io = StringIO.new
    request 'HTTP_X_SENDFILE_TYPE' => 'X-Banana', 'rack.errors' => io do |response|
      response.must_be :ok?
      response.body.must_equal 'Hello World'
      response.headers.wont_include 'x-sendfile'

      io.rewind
      io.read.must_equal "Unknown x-sendfile variation: 'X-Banana'.\n"
    end
  end

  it "sets x-sendfile response header and discards body" do
    request 'HTTP_X_SENDFILE_TYPE' => 'x-sendfile' do |response|
      response.must_be :ok?
      response.body.must_be :empty?
      response.headers['content-length'].must_equal '0'
      response.headers['x-sendfile'].must_equal File.join(Dir.tmpdir,  "rack_sendfile")
    end
  end

  it "closes body when x-sendfile used" do
    body = sendfile_body
    closed = false
    body.define_singleton_method(:close){closed = true}
    request({'HTTP_X_SENDFILE_TYPE' => 'x-sendfile'}, body) do |response|
      response.must_be :ok?
      response.body.must_be :empty?
      response.headers['content-length'].must_equal '0'
      response.headers['x-sendfile'].must_equal File.join(Dir.tmpdir,  "rack_sendfile")
    end
    closed.must_equal true
  end

  it "sets x-lighttpd-send-file response header and discards body" do
    request 'HTTP_X_SENDFILE_TYPE' => 'x-lighttpd-send-file' do |response|
      response.must_be :ok?
      response.body.must_be :empty?
      response.headers['content-length'].must_equal '0'
      response.headers['x-lighttpd-send-file'].must_equal File.join(Dir.tmpdir,  "rack_sendfile")
    end
  end

  it "sets x-accel-redirect response header and discards body" do
    headers = {
      'HTTP_X_SENDFILE_TYPE' => 'x-accel-redirect',
      'HTTP_X_ACCEL_MAPPING' => "#{Dir.tmpdir}/=/foo/bar/"
    }
    request headers do |response|
      response.must_be :ok?
      response.body.must_be :empty?
      response.headers['content-length'].must_equal '0'
      response.headers['x-accel-redirect'].must_equal '/foo/bar/rack_sendfile'
    end
  end

  it "sets x-accel-redirect response header to percent-encoded path" do
    headers = {
      'HTTP_X_SENDFILE_TYPE' => 'x-accel-redirect',
      'HTTP_X_ACCEL_MAPPING' => "#{Dir.tmpdir}/=/foo/bar%/"
    }
    request headers, sendfile_body('file_with_%_?_symbol') do |response|
      response.must_be :ok?
      response.body.must_be :empty?
      response.headers['content-length'].must_equal '0'
      response.headers['x-accel-redirect'].must_equal '/foo/bar%25/file_with_%25_%3F_symbol'
    end
  end

  it 'writes to rack.error when no x-accel-mapping is specified' do
    request 'HTTP_X_SENDFILE_TYPE' => 'x-accel-redirect' do |response|
      response.must_be :ok?
      response.body.must_equal 'Hello World'
      response.headers.wont_include 'x-accel-redirect'
      response.errors.must_include 'x-accel-mapping'
    end
  end

  it 'does nothing when body does not respond to #to_path' do
    request({ 'HTTP_X_SENDFILE_TYPE' => 'x-sendfile' }, ['Not a file...']) do |response|
      response.body.must_equal 'Not a file...'
      response.headers.wont_include 'x-sendfile'
    end
  end

  it "sets x-accel-redirect response header and discards body when initialized with multiple mappings" do
    begin
      dir1 = Dir.mktmpdir
      dir2 = Dir.mktmpdir

      first_body = open_file(File.join(dir1, 'rack_sendfile'))
      first_body.puts 'hello world'

      second_body = open_file(File.join(dir2, 'rack_sendfile'))
      second_body.puts 'goodbye world'

      mappings = [
        ["#{dir1}/", '/foo/bar/'],
        ["#{dir2}/", '/wibble/']
      ]

      request({ 'HTTP_X_SENDFILE_TYPE' => 'x-accel-redirect' }, first_body, mappings) do |response|
        response.must_be :ok?
        response.body.must_be :empty?
        response.headers['content-length'].must_equal '0'
        response.headers['x-accel-redirect'].must_equal '/foo/bar/rack_sendfile'
      end

      request({ 'HTTP_X_SENDFILE_TYPE' => 'x-accel-redirect' }, second_body, mappings) do |response|
        response.must_be :ok?
        response.body.must_be :empty?
        response.headers['content-length'].must_equal '0'
        response.headers['x-accel-redirect'].must_equal '/wibble/rack_sendfile'
      end
    ensure
      FileUtils.remove_entry_secure dir1
      FileUtils.remove_entry_secure dir2
    end
  end

  it "sets x-accel-redirect response header and discards body when initialized with multiple mappings via header" do
    begin
      dir1 = Dir.mktmpdir
      dir2 = Dir.mktmpdir
      dir3 = Dir.mktmpdir

      first_body = open_file(File.join(dir1, 'rack_sendfile'))
      first_body.puts 'hello world'

      second_body = open_file(File.join(dir2, 'rack_sendfile'))
      second_body.puts 'goodbye world'

      third_body = open_file(File.join(dir3, 'rack_sendfile'))
      third_body.puts 'hello again world'

      headers = {
        'HTTP_X_SENDFILE_TYPE' => 'x-accel-redirect',
        'HTTP_X_ACCEL_MAPPING' => "#{dir1}/=/foo/bar/, #{dir2}/=/wibble/"
      }

      request(headers, first_body) do |response|
        response.must_be :ok?
        response.body.must_be :empty?
        response.headers['content-length'].must_equal '0'
        response.headers['x-accel-redirect'].must_equal '/foo/bar/rack_sendfile'
      end

      request(headers, second_body) do |response|
        response.must_be :ok?
        response.body.must_be :empty?
        response.headers['content-length'].must_equal '0'
        response.headers['x-accel-redirect'].must_equal '/wibble/rack_sendfile'
      end

      request(headers, third_body) do |response|
        response.must_be :ok?
        response.body.must_be :empty?
        response.headers['content-length'].must_equal '0'
        response.headers['x-accel-redirect'].must_equal "#{dir3}/rack_sendfile"
      end
    ensure
      FileUtils.remove_entry_secure dir1
      FileUtils.remove_entry_secure dir2
    end
  end
end
