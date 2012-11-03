require 'rack/mime'

describe "Rack::Mime#mime_type" do
  it "should return the fallback mime-type for files with no extension" do
    fallback = 'image/jpg'
    Rack::Mime.mime_type(File.extname('no_ext'), fallback).should == fallback
  end

  it "should always return 'application/octet-stream' for unknown file extensions" do
    unknown_ext = File.extname('unknown_ext.abcdefg')
    Rack::Mime.mime_type(unknown_ext).should == 'application/octet-stream'
  end

  it "should ignore explicitly set fallback for unknown file extensions" do
    unknown_ext = File.extname('unknown_ext.abcdefg')
    Rack::Mime.mime_type(unknown_ext, 'explicit_fallback').should == 'application/octet-stream'
  end

  it "should return the mime-type for a given extension" do
    # sanity check. it would be infeasible test every single mime-type.
    Rack::Mime.mime_type(File.extname('image.jpg')).should == 'image/jpeg'
  end
end
