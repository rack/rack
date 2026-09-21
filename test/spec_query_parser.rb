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

  it "raises when normalizing params with incompatible encoding such as UTF-16LE" do
    query_parser = Rack::QueryParser.make_default(8)
    name = "utf-16le".dup.force_encoding("UTF-16LE")
    value = "Alice?".dup.force_encoding("UTF-16LE")
    lambda {
      query_parser.normalize_params({}, name, value)
    }.must_raise(::Rack::QueryParser::IncompatibleEncodingError)
  end
end
