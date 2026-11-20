# frozen_string_literal: true

require_relative 'helper'

separate_testing do
  require_relative '../lib/rack/query_parser'
end

describe Rack::QueryParser do
  it "can normalize values with missing values" do
    query_parser = Rack::QueryParser.make_default(8)
    query_parser.parse_nested_query("a=a").must_equal({"a" => "a"})
    query_parser.parse_nested_query("a=").must_equal({"a" => ""})
    query_parser.parse_nested_query("a").must_equal({"a" => nil})
    query_parser.parse_query_pairs("a=a").must_equal([["a", "a"]])
    query_parser.parse_query_pairs("a=").must_equal([["a", ""]])
    query_parser.parse_query_pairs("a").must_equal([["a", nil]])
  end

  it "accepts bytesize_limit to specify maximum size of query string to parse" do
    query_parser = Rack::QueryParser.make_default(32, bytesize_limit: 3)
    query_parser.parse_query("a=a").must_equal({"a" => "a"})
    query_parser.parse_nested_query("a=a").must_equal({"a" => "a"})
    query_parser.parse_nested_query("a=a", '&').must_equal({"a" => "a"})
    query_parser.parse_query_pairs("a=a").must_equal([["a", "a"]])
    proc { query_parser.parse_query("a=aa") }.must_raise Rack::QueryParser::QueryLimitError
    proc { query_parser.parse_nested_query("a=aa") }.must_raise Rack::QueryParser::QueryLimitError
    proc { query_parser.parse_nested_query("a=aa", '&') }.must_raise Rack::QueryParser::QueryLimitError
    proc { query_parser.parse_query_pairs("a=aa") }.must_raise Rack::QueryParser::QueryLimitError
  end

  it "does not enforce a bytesize limit when bytesize_limit is nil" do
    query_parser = Rack::QueryParser.make_default(32, bytesize_limit: nil)
    query_parser.parse_query("a=aa").must_equal({"a" => "aa"})
    query_parser.parse_nested_query("a=aa").must_equal({"a" => "aa"})
    query_parser.parse_nested_query("a=aa", '&').must_equal({"a" => "aa"})
    query_parser.parse_query_pairs("a=aa").must_equal([["a", "aa"]])
  end

  it "accepts params_limit to specify maximum number of query parameters to parse" do
    query_parser = Rack::QueryParser.make_default(32, params_limit: 2)
    query_parser.parse_query("a=a&b=b").must_equal({"a" => "a", "b" => "b"})
    query_parser.parse_nested_query("a=a&b=b").must_equal({"a" => "a", "b" => "b"})
    query_parser.parse_nested_query("a=a&b=b", '&').must_equal({"a" => "a", "b" => "b"})
    query_parser.parse_query_pairs("a=a&b=b").must_equal([["a", "a"], ["b", "b"]])
    query_parser.parse_query_pairs("a=1&a=2").must_equal([["a", "1"], ["a", "2"]])
    proc { query_parser.parse_query("a=a&b=b&c=c") }.must_raise Rack::QueryParser::QueryLimitError
    proc { query_parser.parse_nested_query("a=a&b=b&c=c", '&') }.must_raise Rack::QueryParser::QueryLimitError
    proc { query_parser.parse_query("b[]=a&b[]=b&b[]=c") }.must_raise Rack::QueryParser::QueryLimitError
    proc { query_parser.parse_query_pairs("a=a&b=b&c=c") }.must_raise Rack::QueryParser::QueryLimitError
  end

  it "does not enforce a params limit when params_limit is nil" do
    query_parser = Rack::QueryParser.make_default(32, params_limit: nil)
    query_parser.parse_query("a=a&b=b&c=c").must_equal({"a" => "a", "b" => "b", "c" => "c"})
    query_parser.parse_nested_query("a=a&b=b&c=c").must_equal({"a" => "a", "b" => "b", "c" => "c"})
  end

  it "raises when normalizing params with incompatible encoding such as UTF-16LE" do
    query_parser = Rack::QueryParser.make_default(8)
    name = "utf-16le".dup.force_encoding("UTF-16LE")
    value = "Alice?".dup.force_encoding("UTF-16LE")
    lambda {
      query_parser.normalize_params({}, name, value)
    }.must_raise(::Rack::QueryParser::IncompatibleEncodingError)
  end

  it "ignores nil name when normalizing params" do
    params = Rack::QueryParser.make_default(32).make_params
    Rack::QueryParser.make_default(32).normalize_params(params, nil, "v").must_be_nil
    params.to_h.must_equal({})
  end

  it "unescapes keys and values to UTF-8" do
    params = Rack::QueryParser.make_default(32).parse_query("%E3%81%82=a+%2B&b=%FF".b)
    params.must_equal("あ" => "a +", "b" => "\xFF".dup.force_encoding(Encoding::UTF_8))
    params["b"].encoding.must_equal Encoding::UTF_8
    lambda {
      Rack::QueryParser.make_default(32).parse_query("a=%2")
    }.must_raise(Rack::QueryParser::InvalidParameterError).message.must_equal "invalid %-encoding (%2)"
  end

  it "unescapes String subclasses to a String" do
    tagged = Class.new(String).new("a")
    tagged.instance_variable_set(:@tag, true)
    Rack::QueryParser.make_default(32).send(:unescape, tagged).must_be_instance_of String
  end

  it "supports custom unescaper when parsing query" do
    Rack::QueryParser.make_default(32).parse_query("a=b&&c=d") { |s| s.upcase }.
      must_equal("A" => "B", "C" => "D")
  end
end
