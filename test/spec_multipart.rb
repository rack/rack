# frozen_string_literal: true

require_relative 'helper'
require 'timeout'

separate_testing do
  require_relative '../lib/rack/multipart'
  require_relative '../lib/rack/lint'
  require_relative '../lib/rack/mock_request'
  require_relative '../lib/rack/query_parser'
  require_relative '../lib/rack/utils'
  require_relative '../lib/rack/request'
end

describe Rack::Multipart do
  def multipart_fixture(name, boundary = "AaB03x")
    file = multipart_file(name)
    data = File.open(file, 'rb') { |io| io.read }

    type = %(multipart/form-data; boundary=#{boundary})
    length = data.bytesize

    { "CONTENT_TYPE" => type,
      "CONTENT_LENGTH" => length.to_s,
      :input => StringIO.new(data) }
  end

  def multipart_file(name)
    File.join(File.dirname(__FILE__), "multipart", name.to_s)
  end

  it "returns nil if the content type is not multipart" do
    env = Rack::MockRequest.env_for("/", "CONTENT_TYPE" => 'application/x-www-form-urlencoded', :input => "")
    Rack::Multipart.parse_multipart(env).must_be_nil
  end

  it "raises an exception if boundary is too long" do
    env = Rack::MockRequest.env_for("/", multipart_fixture(:content_type_and_no_filename, "A"*71))
    lambda {
      Rack::Multipart.parse_multipart(env)
    }.must_raise Rack::Multipart::BoundaryTooLongError
  end

  it "raises a bad request exception if no body is given but content type indicates a multipart body" do
    env = Rack::MockRequest.env_for("/", "CONTENT_TYPE" => 'multipart/form-data; boundary=BurgerBurger', :input => nil)
    lambda {
      Rack::Multipart.parse_multipart(env)
    }.must_raise Rack::Multipart::MissingInputError
  end

  it "parses multipart content when content type is present but disposition is not" do
    env = Rack::MockRequest.env_for("/", multipart_fixture(:content_type_and_no_disposition))
    params = Rack::Multipart.parse_multipart(env)
    params["text/plain; charset=US-ASCII"].must_equal ["contents"]
  end

  deprecated "parses multipart content when called using Rack::Request#parse_multipart" do
    request = Rack::Request.new(Rack::MockRequest.env_for("/", multipart_fixture(:content_type_and_no_disposition)))
    params = request.send(:parse_multipart)
    params["text/plain; charset=US-ASCII"].must_equal ["contents"]
  end

  it "parses multipart content when content type is present but disposition is not when using IO" do
    read, write = IO.pipe
    env = multipart_fixture(:content_type_and_no_disposition)
    write.write(env[:input].read)
    write.close
    env[:input] = read
    env = Rack::MockRequest.env_for("/", multipart_fixture(:content_type_and_no_disposition))
    params = Rack::Multipart.parse_multipart(env)
    params["text/plain; charset=US-ASCII"].must_equal ["contents"]
  end

  it "parses multipart content when content type present but filename is not" do
    env = Rack::MockRequest.env_for("/", multipart_fixture(:content_type_and_no_filename))
    params = Rack::Multipart.parse_multipart(env)
    params["text"].must_equal "contents"
  end

  it "raises for invalid data preceding the boundary" do
    env = Rack::MockRequest.env_for '/', multipart_fixture(:preceding_boundary)
    lambda {
      Rack::Multipart.parse_multipart(env)
    }.must_raise Rack::Multipart::EmptyContentError
  end

  it "ignores initial end boundaries" do
    env = Rack::MockRequest.env_for '/', multipart_fixture(:end_boundary_first)
    params = Rack::Multipart.parse_multipart(env)
    params["files"][:filename].must_equal "foo"
  end

  it "parses multipart content with different filename and filename*" do
    env = Rack::MockRequest.env_for '/', multipart_fixture(:filename_multi)
    params = Rack::Multipart.parse_multipart(env)
    params["files"][:filename].must_equal "bar"
  end

  it "sets US_ASCII encoding based on charset" do
    env = Rack::MockRequest.env_for("/", multipart_fixture(:content_type_and_no_filename))
    params = Rack::Multipart.parse_multipart(env)
    params["text"].encoding.must_equal Encoding::US_ASCII

    # I'm not 100% sure if making the param name encoding match the
    # content-type charset is the right thing to do.  We should revisit this.
    params.keys.each do |key|
      key.encoding.must_equal Encoding::US_ASCII
    end
  end

  it "sets BINARY encoding for invalid charsets" do
    env = Rack::MockRequest.env_for("/", multipart_fixture(:content_type_and_unknown_charset))
    params = Rack::Multipart.parse_multipart(env)
    params["text"].encoding.must_equal Encoding::BINARY

    # I'm not 100% sure if making the param name encoding match the
    # content-type charset is the right thing to do.  We should revisit this.
    params.keys.each do |key|
      key.encoding.must_equal Encoding::BINARY
    end
  end

  it "sets BINARY encoding on things without content type" do
    env = Rack::MockRequest.env_for("/", multipart_fixture(:none))
    params = Rack::Multipart.parse_multipart(env)
    params["submit-name"].encoding.must_equal Encoding::UTF_8
  end

  it "sets UTF8 encoding on names of things without a content type" do
    env = Rack::MockRequest.env_for("/", multipart_fixture(:none))
    params = Rack::Multipart.parse_multipart(env)
    params.keys.each do |key|
      key.encoding.must_equal Encoding::UTF_8
    end
  end

  it "sets default text to UTF8" do
    env = Rack::MockRequest.env_for("/", multipart_fixture(:text))
    params = Rack::Multipart.parse_multipart(env)
    params['submit-name'].encoding.must_equal Encoding::UTF_8
    params['submit-name-with-content'].encoding.must_equal Encoding::UTF_8
    params.keys.each do |key|
      key.encoding.must_equal Encoding::UTF_8
    end
  end

  it "handles quoted encodings" do
    # See #905
    env = Rack::MockRequest.env_for("/", multipart_fixture(:unity3d_wwwform))
    params = Rack::Multipart.parse_multipart(env)
    params['user_sid'].encoding.must_equal Encoding::UTF_8
  end

  it "parses multipart form webkit style" do
    env = Rack::MockRequest.env_for '/', multipart_fixture(:webkit)
    env['CONTENT_TYPE'] = "multipart/form-data; boundary=----WebKitFormBoundaryWLHCs9qmcJJoyjKR"
    params = Rack::Multipart.parse_multipart(env)
    params['profile']['bio'].must_include 'hello'
    params['profile'].keys.must_include 'public_email'
  end

  it "rejects insanely long boundaries" do
    # using a pipe since a tempfile can use up too much space
    rd, wr = IO.pipe

    # we only call rewind once at start, so make sure it succeeds
    # and doesn't hit ESPIPE
    def rd.rewind; end
    wr.sync = true

    # write to a pipe in a background thread, this will write a lot
    # unless Rack (properly) shuts down the read end
    thr = Thread.new do
      begin
        wr.write("--AaB03x")

        # make the initial boundary a few gigs long
        longer = "0123456789" * 1024 * 1024
        (1024 * 1024).times do
          while wr.write_nonblock(longer, exception: false) == :wait_writable
            Thread.pass
          end
        end

        wr.write("\r\n")
        wr.write('content-disposition: form-data; name="a"; filename="a.txt"')
        wr.write("\r\n")
        wr.write("content-type: text/plain\r\n")
        wr.write("\r\na")
        wr.write("--AaB03x--\r\n")
        wr.close
      rescue => err # this is EPIPE if Rack shuts us down
        err
      end
    end

    fixture = {
      "CONTENT_TYPE" => "multipart/form-data; boundary=AaB03x",
      "CONTENT_LENGTH" => (1024 * 1024 * 8).to_s,
      :input => rd,
    }

    env = Rack::MockRequest.env_for '/', fixture
    lambda {
      Rack::Multipart.parse_multipart(env)
    }.must_raise Rack::Multipart::EmptyContentError
    rd.close

    err = thr.value
    err.must_be_instance_of Errno::EPIPE
    wr.close
  end

  # see https://github.com/rack/rack/pull/1309
  it "parses strange multipart pdf" do
    boundary = '---------------------------932620571087722842402766118'

    data = StringIO.new
    data.write("--#{boundary}")
    data.write("\r\n")
    data.write('content-disposition: form-data; name="a"; filename="a.pdf"')
    data.write("\r\n")
    data.write("content-type:application/pdf\r\n")
    data.write("\r\n")
    data.write("-" * (1024 * 1024))
    data.write("\r\n")
    data.write("--#{boundary}--\r\n")
    data.rewind

    fixture = {
      "CONTENT_TYPE" => "multipart/form-data; boundary=#{boundary}",
      "CONTENT_LENGTH" => data.length.to_s,
      :input => data,
    }

    env = Rack::MockRequest.env_for '/', fixture
    Timeout::timeout(10) { Rack::Multipart.parse_multipart(env) }
  end

  content_disposition_parse = lambda do |params|
    boundary = '---------------------------932620571087722842402766118'

    data = StringIO.new
    data.write("--#{boundary}")
    data.write("\r\n")
    data.write("Content-Disposition: form-data;#{params}")
    data.write("\r\n")
    data.write("content-type:application/pdf\r\n")
    data.write("\r\n")
    data.write("--#{boundary}--\r\n")
    data.rewind

    fixture = {
      "CONTENT_TYPE" => "multipart/form-data; boundary=#{boundary}",
      "CONTENT_LENGTH" => data.length.to_s,
      :input => data,
    }

    env = Rack::MockRequest.env_for '/', fixture
    Rack::Multipart.parse_multipart(env)
  end

  # see https://github.com/rack/rack/issues/2076
  it "parses content-disposition with modification date before the name parameter" do
    x = content_disposition_parse.call(' filename="sample.sql"; modification-date="Wed, 26 Apr 2023 11:01:34 GMT"; size=24; name="file"')
    x.keys.must_equal ["file"]
    x["file"][:filename].must_equal "sample.sql"
    x["file"][:name].must_equal "file"
  end

  it "parses content-disposition with colon in parameter value before the name parameter" do
    x = content_disposition_parse.call(' filename="sam:ple.sql"; name="file"')
    x.keys.must_equal ["file"]
    x["file"][:filename].must_equal "sam:ple.sql"
    x["file"][:name].must_equal "file"
  end

  it "parses content-disposition with name= in parameter value before the name parameter" do
    x = content_disposition_parse.call('filename="name=bar"; name="file"')
    x.keys.must_equal ["file"]
    x["file"][:filename].must_equal "name=bar"
    x["file"][:name].must_equal "file"
  end

  it "parses content-disposition with unquoted parameter values" do
    x = content_disposition_parse.call('filename=sam:ple.sql; name=file')
    x.keys.must_equal ["file"]
    x["file"][:filename].must_equal "sam:ple.sql"
    x["file"][:name].must_equal "file"
  end

  it "parses content-disposition with backslash escaped parameter values" do
    x = content_disposition_parse.call('filename="foo\"bar"; name=file')
    x.keys.must_equal ["file"]
    x["file"][:filename].must_equal "foo\"bar"
    x["file"][:name].must_equal "file"
  end

  it "parses content-disposition with IE full paths in filename" do
    x = content_disposition_parse.call('filename="c:\foo\bar"; name=file;')
    x.keys.must_equal ["file"]
    x["file"][:filename].must_equal "bar"
    x["file"][:name].must_equal "file"
  end

  it "parses content-disposition with escaped parameter values in name" do
    x = content_disposition_parse.call('filename="bar"; name="file\\\\-\\xfoo"')
    x.keys.must_equal ["file\\-xfoo"]
    x["file\\-xfoo"][:filename].must_equal "bar"
    x["file\\-xfoo"][:name].must_equal "file\\-xfoo"
  end

  it "parses content-disposition with escaped parameter values in name" do
    x = content_disposition_parse.call('filename="bar"; name="file\\\\-\\xfoo"')
    x.keys.must_equal ["file\\-xfoo"]
    x["file\\-xfoo"][:filename].must_equal "bar"
    x["file\\-xfoo"][:name].must_equal "file\\-xfoo"
  end

  it "parses up to 16 content-disposition params" do
    x = content_disposition_parse.call("#{14.times.map{|x| "a#{x}=b;"}.join} filename=\"bar\"; name=\"file\"")
    x.keys.must_equal ["file"]
    x["file"][:filename].must_equal "bar"
    x["file"][:name].must_equal "file"
  end

  it "stops parsing content-disposition after 16 params" do
    x = content_disposition_parse.call("#{15.times.map{|x| "a#{x}=b;"}.join} filename=\"bar\"; name=\"file\"")
    x.keys.must_equal ["bar"]
    x["bar"][:filename].must_equal "bar"
    x["bar"][:name].must_equal "bar"
  end

  it "allows content-disposition values up to 1536 bytes" do
    x = content_disposition_parse.call("a=#{'a'*1480}; filename=\"bar\"; name=\"file\"")
    x.keys.must_equal ["file"]
    x["file"][:filename].must_equal "bar"
    x["file"][:name].must_equal "file"
  end

  it "ignores content-disposition values over to 1536 bytes" do
    x = content_disposition_parse.call("a=#{'a'*1510}; filename=\"bar\"; name=\"file\"")
    x.must_equal "application/pdf"=>[""]
  end

  it 'raises an EOF error on content-length mismatch' do
    env = Rack::MockRequest.env_for("/", multipart_fixture(:empty))
    env['rack.input'] = StringIO.new
    assert_raises(EOFError) do
      Rack::Multipart.parse_multipart(env)
    end
  end

  it "parses multipart upload with text file" do
    env = Rack::MockRequest.env_for("/", multipart_fixture(:text))
    params = Rack::Multipart.parse_multipart(env)
    params["submit-name"].must_equal "Larry"
    params["submit-name-with-content"].must_equal "Berry"
    params["files"][:type].must_equal "text/plain"
    params["files"][:filename].must_equal "file1.txt"
    params["files"][:head].must_equal "content-disposition: form-data; " +
      "name=\"files\"; filename=\"file1.txt\"\r\n" +
      "content-type: text/plain\r\n"
    params["files"][:name].must_equal "files"
    params["files"][:tempfile].read.must_equal "contents"
  end

  it "accepts the params hash class to use for multipart parsing" do
    c = Class.new(Rack::QueryParser::Params) do
      def initialize(*)
        super(){|h, k| h[k.to_s] if k.is_a?(Symbol)}
      end
    end
    query_parser = Rack::QueryParser.new c, 100
    env = Rack::MockRequest.env_for("/", multipart_fixture(:text))
    params = Rack::Multipart.parse_multipart(env, query_parser)
    params[:files][:type].must_equal "text/plain"
  end

  it "preserves extension in the created tempfile" do
    env = Rack::MockRequest.env_for("/", multipart_fixture(:text))
    params = Rack::Multipart.parse_multipart(env)
    File.extname(params["files"][:tempfile].path).must_equal ".txt"
  end

  it "parses multipart upload with text file with a no name field" do
    env = Rack::MockRequest.env_for("/", multipart_fixture(:filename_and_no_name))
    params = Rack::Multipart.parse_multipart(env)
    params["file1.txt"][:type].must_equal "text/plain"
    params["file1.txt"][:filename].must_equal "file1.txt"
    params["file1.txt"][:head].must_equal "content-disposition: form-data; " +
      "filename=\"file1.txt\"\r\n" +
      "content-type: text/plain\r\n"
    params["file1.txt"][:name].must_equal "file1.txt"
    params["file1.txt"][:tempfile].read.must_equal "contents"
  end

  it "parses multipart upload file using custom tempfile class" do
    env = Rack::MockRequest.env_for("/", multipart_fixture(:text))
    my_tempfile = "".dup
    env['rack.multipart.tempfile_factory'] = lambda { |filename, content_type| my_tempfile }
    params = Rack::Multipart.parse_multipart(env)
    params["files"][:tempfile].object_id.must_equal my_tempfile.object_id
    my_tempfile.must_equal "contents"
  end

  it "parses multipart upload with nested parameters" do
    env = Rack::MockRequest.env_for("/", multipart_fixture(:nested))
    params = Rack::Multipart.parse_multipart(env)
    params["foo"]["submit-name"].must_equal "Larry"
    params["foo"]["files"][:type].must_equal "text/plain"
    params["foo"]["files"][:filename].must_equal "file1.txt"
    params["foo"]["files"][:head].must_equal "content-disposition: form-data; " +
      "name=\"foo[files]\"; filename=\"file1.txt\"\r\n" +
      "content-type: text/plain\r\n"
    params["foo"]["files"][:name].must_equal "foo[files]"
    params["foo"]["files"][:tempfile].read.must_equal "contents"
  end

  it "parses multipart upload with binary file" do
    env = Rack::MockRequest.env_for("/", multipart_fixture(:binary))
    params = Rack::Multipart.parse_multipart(env)
    params["submit-name"].must_equal "Larry"

    params["files"][:type].must_equal "image/png"
    params["files"][:filename].must_equal "rack-logo.png"
    params["files"][:head].must_equal "content-disposition: form-data; " +
      "name=\"files\"; filename=\"rack-logo.png\"\r\n" +
      "content-type: image/png\r\n"
    params["files"][:name].must_equal "files"
    params["files"][:tempfile].read.length.must_equal 26473
  end

  it "parses multipart upload with an empty file" do
    env = Rack::MockRequest.env_for("/", multipart_fixture(:empty))
    params = Rack::Multipart.parse_multipart(env)
    params["submit-name"].must_equal "Larry"
    params["files"][:type].must_equal "text/plain"
    params["files"][:filename].must_equal "file1.txt"
    params["files"][:head].must_equal "content-disposition: form-data; " +
      "name=\"files\"; filename=\"file1.txt\"\r\n" +
      "content-type: text/plain\r\n"
    params["files"][:name].must_equal "files"
    params["files"][:tempfile].read.must_equal ""
  end

  it "parses multipart upload with a filename containing semicolons" do
    env = Rack::MockRequest.env_for("/", multipart_fixture(:semicolon))
    params = Rack::Multipart.parse_multipart(env)
    params["files"][:type].must_equal "text/plain"
    params["files"][:filename].must_equal "fi;le1.txt"
    params["files"][:head].must_equal "content-disposition: form-data; " +
      "name=\"files\"; filename=\"fi;le1.txt\"\r\n" +
      "content-type: text/plain\r\n"
    params["files"][:name].must_equal "files"
    params["files"][:tempfile].read.must_equal "contents"
  end

  it "parses multipart upload with quoted boundary" do
    env = Rack::MockRequest.env_for("/", multipart_fixture(:quoted, %("AaB:03x")))
    params = Rack::Multipart.parse_multipart(env)
    params["submit-name"].must_equal "Larry"
    params["submit-name-with-content"].must_equal "Berry"
    params["files"][:type].must_equal "text/plain"
    params["files"][:filename].must_equal "file1.txt"
    params["files"][:head].must_equal "content-disposition: form-data; " +
      "name=\"files\"; filename=\"file1.txt\"\r\n" +
      "content-type: text/plain\r\n"
    params["files"][:name].must_equal "files"
    params["files"][:tempfile].read.must_equal "contents"
  end

  it "parses multipart upload with a filename containing invalid characters" do
    env = Rack::MockRequest.env_for("/", multipart_fixture(:invalid_character))
    params = Rack::Multipart.parse_multipart(env)
    params["files"][:type].must_equal "text/plain"
    params["files"][:filename].must_match(/invalid/)
    head = "content-disposition: form-data; " +
      "name=\"files\"; filename=\"invalid\xC3.txt\"\r\n" +
      "content-type: text/plain\r\n"
    head = head.force_encoding(Encoding::ASCII_8BIT)
    params["files"][:head].must_equal head
    params["files"][:name].must_equal "files"
    params["files"][:tempfile].read.must_equal "contents"
  end

  it "parses multipart form with an encoded word filename" do
    env = Rack::MockRequest.env_for '/', multipart_fixture(:filename_with_encoded_words)
    params = Rack::Multipart.parse_multipart(env)
    params["files"][:filename].must_equal "файл"
  end

  it "parses multipart form with a single quote in the filename" do
    env = Rack::MockRequest.env_for '/', multipart_fixture(:filename_with_single_quote)
    params = Rack::Multipart.parse_multipart(env)
    params["files"][:filename].must_equal "bob's flowers.jpg"
  end

  it "parses multipart form with a null byte in the filename" do
    env = Rack::MockRequest.env_for '/', multipart_fixture(:filename_with_null_byte)
    params = Rack::Multipart.parse_multipart(env)
    params["files"][:filename].must_equal "flowers.exe\u0000.jpg"
  end

  it "is robust separating content-disposition fields" do
    env = Rack::MockRequest.env_for("/", multipart_fixture(:robust_field_separation))
    params = Rack::Multipart.parse_multipart(env)
    params["text"].must_equal "contents"
  end

  it "does not include file params if no file was selected" do
    env = Rack::MockRequest.env_for("/", multipart_fixture(:none))
    params = Rack::Multipart.parse_multipart(env)
    params["submit-name"].must_equal "Larry"
    params["files"].must_be_nil
    params.keys.wont_include "files"
  end

  it "parses multipart/mixed" do
    env = Rack::MockRequest.env_for("/", multipart_fixture(:mixed_files))
    params = Rack::Multipart.parse_multipart(env)
    params["foo"].must_equal "bar"
    params["files"].must_be_instance_of String
    params["files"].size.must_equal 252
  end

  it "parses IE multipart upload and cleans up the filename" do
    env = Rack::MockRequest.env_for("/", multipart_fixture(:ie))
    params = Rack::Multipart.parse_multipart(env)
    params["files"][:type].must_equal "text/plain"
    params["files"][:filename].must_equal "file1.txt"
    params["files"][:head].must_equal "content-disposition: form-data; " +
      "name=\"files\"; " +
      'filename="C:\Documents and Settings\Administrator\Desktop\file1.txt"' +
      "\r\ncontent-type: text/plain\r\n"
    params["files"][:name].must_equal "files"
    params["files"][:tempfile].read.must_equal "contents"
  end

  it "parses filename and modification param" do
    env = Rack::MockRequest.env_for("/", multipart_fixture(:filename_and_modification_param))
    params = Rack::Multipart.parse_multipart(env)
    params["files"][:type].must_equal "image/jpeg"
    params["files"][:filename].must_equal "genome.jpeg"
    params["files"][:head].must_equal "content-type: image/jpeg\r\n" +
      "content-disposition: attachment; " +
      "name=\"files\"; " +
      "filename=genome.jpeg; " +
      "modification-date=\"Wed, 12 Feb 1997 16:29:51 -0500\";\r\n" +
      "Content-Description: a complete map of the human genome\r\n"
    params["files"][:name].must_equal "files"
    params["files"][:tempfile].read.must_equal "contents"
  end

  it "parses filename with escaped quotes" do
    env = Rack::MockRequest.env_for("/", multipart_fixture(:filename_with_escaped_quotes))
    params = Rack::Multipart.parse_multipart(env)
    params["files"][:type].must_equal "application/octet-stream"
    params["files"][:filename].must_equal "escape \"quotes"
    params["files"][:head].must_equal "content-disposition: form-data; " +
      "name=\"files\"; " +
      "filename=\"escape \\\"quotes\"\r\n" +
      "content-type: application/octet-stream\r\n"
    params["files"][:name].must_equal "files"
    params["files"][:tempfile].read.must_equal "contents"
  end

  it "parses filename with plus character" do
    env = Rack::MockRequest.env_for("/", multipart_fixture(:filename_with_plus))
    params = Rack::Multipart.parse_multipart(env)
    params["files"][:type].must_equal "application/octet-stream"
    params["files"][:filename].must_equal "foo+bar"
    params["files"][:head].must_equal "content-disposition: form-data; " +
      "name=\"files\"; " +
      "filename=\"foo+bar\"\r\n" +
      "content-type: application/octet-stream\r\n"
    params["files"][:name].must_equal "files"
    params["files"][:tempfile].read.must_equal "contents"
  end

  it "parses filename with percent escaped quotes" do
    env = Rack::MockRequest.env_for("/", multipart_fixture(:filename_with_percent_escaped_quotes))
    params = Rack::Multipart.parse_multipart(env)
    params["files"][:type].must_equal "application/octet-stream"
    params["files"][:filename].must_equal "escape \"quotes"
    params["files"][:head].must_equal "content-disposition: form-data; " +
      "name=\"files\"; " +
      "filename=\"escape %22quotes\"\r\n" +
      "content-type: application/octet-stream\r\n"
    params["files"][:name].must_equal "files"
    params["files"][:tempfile].read.must_equal "contents"
  end

  it "parses filename with escaped quotes and modification param" do
    env = Rack::MockRequest.env_for("/", multipart_fixture(:filename_with_escaped_quotes_and_modification_param))
    params = Rack::Multipart.parse_multipart(env)
    params["files"][:type].must_equal "image/jpeg"
    params["files"][:filename].must_equal "\"human\" genome.jpeg"
    params["files"][:head].must_equal "content-type: image/jpeg\r\n" +
      "content-disposition: attachment; " +
      "name=\"files\"; " +
      "filename=\"\\\"human\\\" genome.jpeg\"; " +
      "modification-date=\"Wed, 12 Feb 1997 16:29:51 -0500\";\r\n" +
      "Content-Description: a complete map of the human genome\r\n"
    params["files"][:name].must_equal "files"
    params["files"][:tempfile].read.must_equal "contents"
  end

  it "parses filename with unescaped percentage characters" do
    env = Rack::MockRequest.env_for("/", multipart_fixture(:filename_with_unescaped_percentages, "----WebKitFormBoundary2NHc7OhsgU68l3Al"))
    params = Rack::Multipart.parse_multipart(env)
    files = params["document"]["attachment"]
    files[:type].must_equal "image/jpeg"
    files[:filename].must_equal "100% of a photo.jpeg"
    files[:head].must_equal <<-MULTIPART
content-disposition: form-data; name="document[attachment]"; filename="100% of a photo.jpeg"\r
content-type: image/jpeg\r
    MULTIPART

    files[:name].must_equal "document[attachment]"
    files[:tempfile].read.must_equal "contents"
  end

  it "parses filename with unescaped percentage characters that look like partial hex escapes" do
    env = Rack::MockRequest.env_for("/", multipart_fixture(:filename_with_unescaped_percentages2, "----WebKitFormBoundary2NHc7OhsgU68l3Al"))
    params = Rack::Multipart.parse_multipart(env)
    files = params["document"]["attachment"]
    files[:type].must_equal "image/jpeg"
    files[:filename].must_equal "100%a"
    files[:head].must_equal <<-MULTIPART
content-disposition: form-data; name="document[attachment]"; filename="100%a"\r
content-type: image/jpeg\r
    MULTIPART

    files[:name].must_equal "document[attachment]"
    files[:tempfile].read.must_equal "contents"
  end

  it "parses filename with unescaped percentage characters that look like partial hex escapes" do
    env = Rack::MockRequest.env_for("/", multipart_fixture(:filename_with_unescaped_percentages3, "----WebKitFormBoundary2NHc7OhsgU68l3Al"))
    params = Rack::Multipart.parse_multipart(env)
    files = params["document"]["attachment"]
    files[:type].must_equal "image/jpeg"
    files[:filename].must_equal "100%"
    files[:head].must_equal <<-MULTIPART
content-disposition: form-data; name="document[attachment]"; filename="100%"\r
content-type: image/jpeg\r
    MULTIPART

    files[:name].must_equal "document[attachment]"
    files[:tempfile].read.must_equal "contents"
  end

  it "raises a RuntimeError for invalid file path" do
    proc{Rack::Multipart::UploadedFile.new('non-existant')}.must_raise RuntimeError
  end

  it "supports uploading files in binary mode" do
    Rack::Multipart::UploadedFile.new(multipart_file("file1.txt")).wont_be :binmode?
    Rack::Multipart::UploadedFile.new(multipart_file("file1.txt"), binary: true).must_be :binmode?
  end

  it "builds multipart body" do
    files = Rack::Multipart::UploadedFile.new(multipart_file("file1.txt"))
    data  = Rack::Multipart.build_multipart("submit-name" => "Larry", "files" => files)

    options = {
      "CONTENT_TYPE" => "multipart/form-data; boundary=AaB03x",
      "CONTENT_LENGTH" => data.length.to_s,
      :input => StringIO.new(data)
    }
    env = Rack::MockRequest.env_for("/", options)
    params = Rack::Multipart.parse_multipart(env)
    params["submit-name"].must_equal "Larry"
    params["files"][:filename].must_equal "file1.txt"
    params["files"][:tempfile].read.must_equal "contents"
  end

  it "builds multipart filename with space" do
    files = Rack::Multipart::UploadedFile.new(multipart_file("space case.txt"))
    data  = Rack::Multipart.build_multipart("submit-name" => "Larry", "files" => files)

    options = {
      "CONTENT_TYPE" => "multipart/form-data; boundary=AaB03x",
      "CONTENT_LENGTH" => data.length.to_s,
      :input => StringIO.new(data)
    }
    env = Rack::MockRequest.env_for("/", options)
    params = Rack::Multipart.parse_multipart(env)
    params["submit-name"].must_equal "Larry"
    params["files"][:filename].must_equal "space case.txt"
    params["files"][:tempfile].read.must_equal "contents"
  end

  it "builds nested multipart body using array" do
    files = Rack::Multipart::UploadedFile.new(multipart_file("file1.txt"))
    data  = Rack::Multipart.build_multipart("people" => [{ "submit-name" => "Larry", "files" => files }])

    options = {
      "CONTENT_TYPE" => "multipart/form-data; boundary=AaB03x",
      "CONTENT_LENGTH" => data.length.to_s,
      :input => StringIO.new(data)
    }
    env = Rack::MockRequest.env_for("/", options)
    params = Rack::Multipart.parse_multipart(env)
    params["people"][0]["submit-name"].must_equal "Larry"
    params["people"][0]["files"][:filename].must_equal "file1.txt"
    params["people"][0]["files"][:tempfile].read.must_equal "contents"
  end

  it "builds nested multipart body using hash" do
    files = Rack::Multipart::UploadedFile.new(multipart_file("file1.txt"))
    data  = Rack::Multipart.build_multipart("people" => { "foo" => { "submit-name" => "Larry", "files" => files } })

    options = {
      "CONTENT_TYPE" => "multipart/form-data; boundary=AaB03x",
      "CONTENT_LENGTH" => data.length.to_s,
      :input => StringIO.new(data)
    }
    env = Rack::MockRequest.env_for("/", options)
    params = Rack::Multipart.parse_multipart(env)
    params["people"]["foo"]["submit-name"].must_equal "Larry"
    params["people"]["foo"]["files"][:filename].must_equal "file1.txt"
    params["people"]["foo"]["files"][:tempfile].read.must_equal "contents"
  end

  it "builds multipart body from StringIO" do
    files = Rack::Multipart::UploadedFile.new(io: StringIO.new('foo'), filename: 'bar.txt')
    data  = Rack::Multipart.build_multipart("submit-name" => "Larry", "files" => files)

    options = {
      "CONTENT_TYPE" => "multipart/form-data; boundary=AaB03x",
      "CONTENT_LENGTH" => data.length.to_s,
      :input => StringIO.new(data)
    }
    env = Rack::MockRequest.env_for("/", options)
    params = Rack::Multipart.parse_multipart(env)
    params["submit-name"].must_equal "Larry"
    params["files"][:filename].must_equal "bar.txt"
    params["files"][:tempfile].read.must_equal "foo"
  end

  it "can parse fields that end at the end of the buffer" do
    input = File.read(multipart_file("bad_robots"))

    req = Rack::Request.new Rack::MockRequest.env_for("/",
                      "CONTENT_TYPE" => "multipart/form-data; boundary=1yy3laWhgX31qpiHinh67wJXqKalukEUTvqTzmon",
                      "CONTENT_LENGTH" => input.size,
                      :input => input)

    req.POST['file.path'].must_equal "/var/tmp/uploads/4/0001728414"
    req.POST['addresses'].wont_equal nil
  end

  it "builds complete params with the chunk size of 16384 slicing exactly on boundary" do
    begin
      previous_limit = Rack::Utils.multipart_part_limit
      Rack::Utils.multipart_part_limit = 256

      data = File.open(multipart_file("fail_16384_nofile"), 'rb') { |f| f.read }.gsub(/\n/, "\r\n")
      options = {
        "CONTENT_TYPE" => "multipart/form-data; boundary=----WebKitFormBoundaryWsY0GnpbI5U7ztzo",
        "CONTENT_LENGTH" => data.length.to_s,
        :input => StringIO.new(data)
      }
      env = Rack::MockRequest.env_for("/", options)
      params = Rack::Multipart.parse_multipart(env)

      params.wont_equal nil
      params.keys.must_include "AAAAAAAAAAAAAAAAAAA"
      params["AAAAAAAAAAAAAAAAAAA"].keys.must_include "PLAPLAPLA_MEMMEMMEMM_ATTRATTRER"
      params["AAAAAAAAAAAAAAAAAAA"]["PLAPLAPLA_MEMMEMMEMM_ATTRATTRER"].keys.must_include "new"
      params["AAAAAAAAAAAAAAAAAAA"]["PLAPLAPLA_MEMMEMMEMM_ATTRATTRER"]["new"].keys.must_include "-2"
      params["AAAAAAAAAAAAAAAAAAA"]["PLAPLAPLA_MEMMEMMEMM_ATTRATTRER"]["new"]["-2"].keys.must_include "ba_unit_id"
      params["AAAAAAAAAAAAAAAAAAA"]["PLAPLAPLA_MEMMEMMEMM_ATTRATTRER"]["new"]["-2"]["ba_unit_id"].must_equal "1017"
    ensure
      Rack::Utils.multipart_part_limit = previous_limit
    end
  end

  it "does not reach a multi-part limit" do
    begin
      previous_limit = Rack::Utils.multipart_part_limit
      Rack::Utils.multipart_part_limit = 4

      env = Rack::MockRequest.env_for '/', multipart_fixture(:three_files_three_fields)
      params = Rack::Multipart.parse_multipart(env)
      params['reply'].must_equal 'yes'
      params['to'].must_equal 'people'
      params['from'].must_equal 'others'
    ensure
      Rack::Utils.multipart_part_limit = previous_limit
    end
  end

  it "treats a multipart limit of 0 as no limit" do
    begin
      previous_limit = Rack::Utils.multipart_part_limit
      Rack::Utils.multipart_part_limit = 0

      env = Rack::MockRequest.env_for '/', multipart_fixture(:three_files_three_fields)
      params = Rack::Multipart.parse_multipart(env)
      params['reply'].must_equal 'yes'
      params['to'].must_equal 'people'
      params['from'].must_equal 'others'
    ensure
      Rack::Utils.multipart_part_limit = previous_limit
    end
  end

  it "treats a multipart limit of 0 as no limit" do
    begin
      previous_limit = Rack::Utils.multipart_total_part_limit
      Rack::Utils.multipart_total_part_limit = 0

      env = Rack::MockRequest.env_for '/', multipart_fixture(:three_files_three_fields)
      params = Rack::Multipart.parse_multipart(env)
      params['reply'].must_equal 'yes'
      params['to'].must_equal 'people'
      params['from'].must_equal 'others'
    ensure
      Rack::Utils.multipart_total_part_limit = previous_limit
    end
  end

  it "reaches a multipart file limit" do
    begin
      previous_limit = Rack::Utils.multipart_part_limit
      Rack::Utils.multipart_part_limit = 3

      env = Rack::MockRequest.env_for '/', multipart_fixture(:three_files_three_fields)
      lambda { Rack::Multipart.parse_multipart(env) }.must_raise Rack::Multipart::MultipartPartLimitError
    ensure
      Rack::Utils.multipart_part_limit = previous_limit
    end
  end

  it "reaches a multipart total limit" do
    begin
      previous_limit = Rack::Utils.multipart_total_part_limit
      Rack::Utils.multipart_total_part_limit = 5

      env = Rack::MockRequest.env_for '/', multipart_fixture(:three_files_three_fields)
      lambda { Rack::Multipart.parse_multipart(env) }.must_raise Rack::Multipart::MultipartTotalPartLimitError
    ensure
      Rack::Utils.multipart_total_part_limit = previous_limit
    end
  end

  it "returns nil if no UploadedFiles were used" do
    data = Rack::Multipart.build_multipart("people" => [{ "submit-name" => "Larry", "files" => "contents" }])
    data.must_be_nil
  end

  it "raises ArgumentError if params is not a Hash" do
    lambda {
      Rack::Multipart.build_multipart("foo=bar")
    }.must_raise(ArgumentError).message.must_equal "value must be a Hash"
  end

  it "is able to parse fields with a content type" do
    data = <<-EOF
--1yy3laWhgX31qpiHinh67wJXqKalukEUTvqTzmon\r
content-disposition: form-data; name="description"\r
content-type: text/plain"\r
\r
Very very blue\r
--1yy3laWhgX31qpiHinh67wJXqKalukEUTvqTzmon--\r
EOF
    options = {
      "CONTENT_TYPE" => "multipart/form-data; boundary=1yy3laWhgX31qpiHinh67wJXqKalukEUTvqTzmon",
      "CONTENT_LENGTH" => data.length.to_s,
      :input => StringIO.new(data)
    }
    env = Rack::MockRequest.env_for("/", options)
    params = Rack::Multipart.parse_multipart(env)

    params.must_equal "description" => "Very very blue"
  end

  it "parses multipart upload with no content-length header" do
    env = Rack::MockRequest.env_for '/', multipart_fixture(:webkit)
    env['CONTENT_TYPE'] = "multipart/form-data; boundary=----WebKitFormBoundaryWLHCs9qmcJJoyjKR"
    env.delete 'CONTENT_LENGTH'
    params = Rack::Multipart.parse_multipart(env)
    params['profile']['bio'].must_include 'hello'
  end

  ['', '"'].each do |quote_char|
    it "parses very long #{'un' if quote_char.empty?}quoted multipart file names" do
      data = <<-EOF
--AaB03x\r
content-type: text/plain\r
content-disposition: attachment; name=file; filename=#{quote_char}#{'long' * 100}#{quote_char}\r
\r
contents\r
--AaB03x--\r
      EOF

      options = {
        "CONTENT_TYPE" => "multipart/form-data; boundary=AaB03x",
        "CONTENT_LENGTH" => data.length.to_s,
        :input => StringIO.new(data)
      }
      env = Rack::MockRequest.env_for("/", options)
      params = Rack::Multipart.parse_multipart(env)

      params["file"][:filename].must_equal 'long' * 100
    end
  end

  it "does not remove escaped quotes in filenames" do
    data = <<-EOF
--AaB03x\r
content-type: text/plain\r
content-disposition: attachment; name=file; filename="\\"#{'long' * 100}\\""\r
\r
contents\r
--AaB03x--\r
    EOF

    options = {
      "CONTENT_TYPE" => "multipart/form-data; boundary=AaB03x",
      "CONTENT_LENGTH" => data.length.to_s,
      :input => StringIO.new(data)
    }
    env = Rack::MockRequest.env_for("/", options)
    params = Rack::Multipart.parse_multipart(env)

    params["file"][:filename].must_equal "\"#{'long' * 100}\""
  end

  it "limits very long file name extensions in multipart tempfiles" do
    data = <<-EOF
--AaB03x\r
content-type: text/plain\r
content-disposition: attachment; name=file; filename=foo.#{'a' * 1000}\r
\r
contents\r
--AaB03x--\r
    EOF

    options = {
      "CONTENT_TYPE" => "multipart/form-data; boundary=AaB03x",
      "CONTENT_LENGTH" => data.length.to_s,
      :input => StringIO.new(data)
    }
    env = Rack::MockRequest.env_for("/", options)
    params = Rack::Multipart.parse_multipart(env)

    params["file"][:filename].must_equal "foo.#{'a' * 1000}"
    File.extname(env["rack.tempfiles"][0]).must_equal ".#{'a' * 128}"
  end

  it "parses unquoted parameter values at end of line" do
    data = <<-EOF
--AaB03x\r
content-type: text/plain\r
content-disposition: attachment; name=inline\r
\r
true\r
--AaB03x--\r
    EOF

    options = {
      "CONTENT_TYPE" => "multipart/form-data; boundary=AaB03x",
      "CONTENT_LENGTH" => data.length.to_s,
      :input => StringIO.new(data)
    }
    env = Rack::MockRequest.env_for("/", options)
    params = Rack::Multipart.parse_multipart(env)
    params["inline"].must_equal 'true'
  end

  it "parses quoted chars in name parameter" do
    data = <<-EOF
--AaB03x\r
content-type: text/plain\r
content-disposition: attachment; name="quoted\\\\chars\\"in\rname"\r
\r
true\r
--AaB03x--\r
    EOF

    options = {
      "CONTENT_TYPE" => "multipart/form-data; boundary=AaB03x",
      "CONTENT_LENGTH" => data.length.to_s,
      :input => StringIO.new(data)
    }
    env = Rack::MockRequest.env_for("/", options)
    params = Rack::Multipart.parse_multipart(env)
    params["quoted\\chars\"in\rname"].must_equal 'true'
  end

  it "supports mixed case metadata" do
    file = multipart_file(:text)
    data = File.open(file, 'rb') { |io| io.read }

    type = "Multipart/Form-Data; Boundary=AaB03x"
    length = data.bytesize

    e = { "CONTENT_TYPE" => type,
      "CONTENT_LENGTH" => length.to_s,
      :input => StringIO.new(data) }

    env = Rack::MockRequest.env_for("/", e)
    params = Rack::Multipart.parse_multipart(env)
    params["submit-name"].must_equal "Larry"
    params["submit-name-with-content"].must_equal "Berry"
    params["files"][:type].must_equal "text/plain"
    params["files"][:filename].must_equal "file1.txt"
    params["files"][:head].must_equal "content-disposition: form-data; " +
      "name=\"files\"; filename=\"file1.txt\"\r\n" +
      "content-type: text/plain\r\n"
    params["files"][:name].must_equal "files"
    params["files"][:tempfile].read.must_equal "contents"
  end

  it "falls back to content-type for the name" do
    rack_logo = File.read(multipart_file("rack-logo.png"))

    data = <<-EOF.dup
--AaB03x\r
content-type: text/plain\r
\r
some text\r
--AaB03x\r
\r
\r
some more text (I didn't specify content-type)\r
--AaB03x\r
content-type: image/png\r
\r
#{rack_logo}\r
--AaB03x--\r
    EOF

    options = {
      "CONTENT_TYPE" => "multipart/related; boundary=AaB03x",
      "CONTENT_LENGTH" => data.bytesize.to_s,
      :input => StringIO.new(data.dup)
    }
    env = Rack::MockRequest.env_for("/", options)
    params = Rack::Multipart.parse_multipart(env)

    params["text/plain"].must_equal ["some text", "some more text (I didn't specify content-type)"]
    params["image/png"].length.must_equal 1

    f = Tempfile.new("rack-logo")
    f.write(params["image/png"][0])
    f.length.must_equal 26473
  end

  it "supports ISO-2022-JP-encoded part" do
    env = Rack::MockRequest.env_for("/", multipart_fixture(:multiple_encodings))
    params = Rack::Multipart.parse_multipart(env)
    params["us-ascii"].must_equal("Alice")
    params["iso-2022-jp"].must_equal("アリス")
  end
end
