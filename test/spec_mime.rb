require 'rack/mime'

describe Rack::Mime do

  it "should return the fallback mime-type for files with no extension" do
    fallback = 'image/jpg'
    Rack::Mime.mime_type(File.extname('no_ext'), fallback).should == fallback
  end

  it "should always return 'application/octet-stream' for unknown file extensions" do
    unknown_ext = File.extname('unknown_ext.abcdefg')
    Rack::Mime.mime_type(unknown_ext).should == 'application/octet-stream'
  end

  it "should return the mime-type for a given extension" do
    # sanity check. it would be infeasible test every single mime-type.
    Rack::Mime.mime_type(File.extname('image.jpg')).should == 'image/jpeg'
  end

  it "should support null fallbacks" do
    Rack::Mime.mime_type('.nothing', nil).should == nil
  end

  it "should match exact mimes" do
    Rack::Mime.match?('text/html', 'text/html').should == true
    Rack::Mime.match?('text/html', 'text/meme').should == false
    Rack::Mime.match?('text', 'text').should == true
    Rack::Mime.match?('text', 'binary').should == false
  end

  it "should match class wildcard mimes" do
    Rack::Mime.match?('text/html', 'text/*').should == true
    Rack::Mime.match?('text/plain', 'text/*').should == true
    Rack::Mime.match?('application/json', 'text/*').should == false
    Rack::Mime.match?('text/html', 'text').should == true
  end

  it "should match full wildcards" do
    Rack::Mime.match?('text/html', '*').should == true
    Rack::Mime.match?('text/plain', '*').should == true
    Rack::Mime.match?('text/html', '*/*').should == true
    Rack::Mime.match?('text/plain', '*/*').should == true
  end

  it "should match type wildcard mimes" do
    Rack::Mime.match?('text/html', '*/html').should == true
    Rack::Mime.match?('text/plain', '*/plain').should == true
  end

end

