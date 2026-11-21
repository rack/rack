# frozen_string_literal: true

require_relative 'helper'

separate_testing do
  require_relative '../lib/rack/mime'
end

describe Rack::Mime do

  it "should return the fallback mime-type for files with no extension" do
    fallback = 'image/jpg'
    Rack::Mime.mime_type(File.extname('no_ext'), fallback).must_equal fallback
  end

  it "should always return 'application/octet-stream' for unknown file extensions" do
    unknown_ext = File.extname('unknown_ext.abcdefg')
    Rack::Mime.mime_type(unknown_ext).must_equal 'application/octet-stream'
  end

  it "should return the mime-type for a given extension" do
    # sanity check. it would be infeasible test every single mime-type.
    Rack::Mime.mime_type(File.extname('image.jpg')).must_equal 'image/jpeg'
  end

  it "should support null fallbacks" do
    Rack::Mime.mime_type('.nothing', nil).must_be_nil
  end

  it "should return registered mime-types" do
    types = Rack::Mime.send(:mime_types)
    saved = types.dup
    begin
      Rack::Mime.register('.rackfoo' => 'text/foo', '.txt' => 'text/x-plain').must_be_nil
      Rack::Mime.mime_type('.rackfoo').must_equal 'text/foo'
      Rack::Mime.mime_type('.RACKFOO').must_equal 'text/foo'
      Rack::Mime.mime_type('.txt').must_equal 'text/x-plain'
    ensure
      types.replace(saved)
    end
  end

  it "should warn that MIME_TYPES is deprecated" do
    deprecated, Warning[:deprecated] = Warning[:deprecated], true
    capture_warnings(Warning) do |warnings|
      Rack::Mime::MIME_TYPES.size
      warnings.pop(true).first.must_include 'constant Rack::Mime::MIME_TYPES is deprecated'
    end
  ensure
    Warning[:deprecated] = deprecated
  end

  deprecated "should still allow adding mime-types through MIME_TYPES" do
    types = Rack::Mime::MIME_TYPES
    saved = types.dup
    begin
      types['.rackbar'] = 'text/bar'
      Rack::Mime.mime_type('.rackbar').must_equal 'text/bar'
    ensure
      types.replace(saved)
    end
  end

  it "should match exact mimes" do
    Rack::Mime.match?('text/html', 'text/html').must_equal true
    Rack::Mime.match?('text/html', 'text/meme').must_equal false
    Rack::Mime.match?('text', 'text').must_equal true
    Rack::Mime.match?('text', 'binary').must_equal false
  end

  it "should match class wildcard mimes" do
    Rack::Mime.match?('text/html', 'text/*').must_equal true
    Rack::Mime.match?('text/plain', 'text/*').must_equal true
    Rack::Mime.match?('application/json', 'text/*').must_equal false
    Rack::Mime.match?('text/html', 'text').must_equal true
  end

  it "should match full wildcards" do
    Rack::Mime.match?('text/html', '*').must_equal true
    Rack::Mime.match?('text/plain', '*').must_equal true
    Rack::Mime.match?('text/html', '*/*').must_equal true
    Rack::Mime.match?('text/plain', '*/*').must_equal true
  end

  it "should match type wildcard mimes" do
    Rack::Mime.match?('text/html', '*/html').must_equal true
    Rack::Mime.match?('text/plain', '*/plain').must_equal true
  end

end
