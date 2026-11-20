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
  end

  it "accepts bytesize_limit to specify maximum size of query string to parse" do
    query_parser = Rack::QueryParser.make_default(32, bytesize_limit: 3)
    query_parser.parse_query("a=a").must_equal({"a" => "a"})
    query_parser.parse_nested_query("a=a").must_equal({"a" => "a"})
    query_parser.parse_nested_query("a=a", '&').must_equal({"a" => "a"})
    proc { query_parser.parse_query("a=aa") }.must_raise Rack::QueryParser::QueryLimitError
    proc { query_parser.parse_nested_query("a=aa") }.must_raise Rack::QueryParser::QueryLimitError
    proc { query_parser.parse_nested_query("a=aa", '&') }.must_raise Rack::QueryParser::QueryLimitError
  end

  it "accepts params_limit to specify maximum number of query parameters to parse" do
    query_parser = Rack::QueryParser.make_default(32, params_limit: 2)
    query_parser.parse_query("a=a&b=b").must_equal({"a" => "a", "b" => "b"})
    query_parser.parse_nested_query("a=a&b=b").must_equal({"a" => "a", "b" => "b"})
    query_parser.parse_nested_query("a=a&b=b", '&').must_equal({"a" => "a", "b" => "b"})
    proc { query_parser.parse_query("a=a&b=b&c=c") }.must_raise Rack::QueryParser::QueryLimitError
    proc { query_parser.parse_nested_query("a=a&b=b&c=c", '&') }.must_raise Rack::QueryParser::QueryLimitError
    proc { query_parser.parse_query("b[]=a&b[]=b&b[]=c") }.must_raise Rack::QueryParser::QueryLimitError
  end

  it "ignores spaces after the separator" do
    query_parser = Rack::QueryParser.make_default(32)
    query_parser.parse_query("a=1&   b=2").must_equal({"a" => "1", "b" => "2"})
    query_parser.parse_nested_query("a=1&   b=2").must_equal({"a" => "1", "b" => "2"})
    query_parser.parse_nested_query("a=1&   ").must_equal({"a" => "1"})
    query_parser.parse_nested_query("a=1&&&b=2").must_equal({"a" => "1", "b" => "2"})
    query_parser.parse_nested_query("a=1& & &b=2").must_equal({"a" => "1", "b" => "2"})
    query_parser.parse_nested_query("a=1&  b[]=2&  b[]=3").must_equal({"a" => "1", "b" => ["2", "3"]})
    query_parser.parse_nested_query("a=1;   b=2", ";").must_equal({"a" => "1", "b" => "2"})
    query_parser.parse_nested_query(";key;", ";,").must_equal({"key" => nil})
    query_parser.parse_nested_query(",foo=bar;  ,", ";,").must_equal({"foo" => "bar"})
    query_parser.parse_nested_query("a=1|   b=2", "|").must_equal({"a" => "1", "b" => "2"})
    query_parser.parse_nested_query("a=1|   b=2", "|&").must_equal({"a" => "1", "b" => "2"})
  end

  it "only ignores spaces, not other whitespace, and only at the start of a pair" do
    query_parser = Rack::QueryParser.make_default(32)
    query_parser.parse_nested_query("a=1&\tb=2").must_equal({"a" => "1", "\tb" => "2"})
    query_parser.parse_nested_query("a= 1&b=2 ").must_equal({"a" => " 1", "b" => "2 "})
    query_parser.parse_nested_query("a=1&b =2").must_equal({"a" => "1", "b " => "2"})
  end

  it "ignores spaces before the first pair" do
    # Spaces were previously only ignored after a separator, so the first
    # pair kept them. A query string should not contain unencoded spaces.
    query_parser = Rack::QueryParser.make_default(32)
    query_parser.parse_nested_query("  a=1").must_equal({"a" => "1"})
    query_parser.parse_nested_query("  ").must_equal({})
  end

  it "does not allocate regexp backtracking state for spaces after the separator" do
    # GHSA-f7cc-57h7-qrcg: the separator was matched with /& */n, and the
    # regexp engine allocates about 48 bytes of backtracking state for every
    # space matched by the quantifier, so this input used to allocate ~48MB.
    # Ruby does not account for that memory in GC.stat or ObjectSpace, so the
    # memory use was verified by measuring the process RSS; this only checks
    # that the input is still parsed correctly.
    query_parser = Rack::QueryParser.make_default(32)
    qs = "a=1&#{' ' * 1_000_000}b=2"
    query_parser.parse_query(qs).must_equal({"a" => "1", "b" => "2"})
    query_parser.parse_nested_query(qs).must_equal({"a" => "1", "b" => "2"})
    query_parser.parse_nested_query(qs.tr('&', ';'), ';').must_equal({"a" => "1", "b" => "2"})
    query_parser.parse_nested_query("a=1&#{' ' * 1_000_000}").must_equal({"a" => "1"})
  end

  it "does not allocate regexp backtracking state for brackets in nested parameter names" do
    # GHSA-f7cc-57h7-qrcg: params_hash_has_key? split the name on /[\[\]]+/,
    # which allocates about 48 bytes of backtracking state per bracket, and
    # is reached by the second x[][y] parameter within the default limits.
    # As above, this only checks that the input is still parsed correctly.
    query_parser = Rack::QueryParser.make_default(32)
    brackets = "[" * 1_000_000
    query_parser.parse_nested_query("a[][b]=1&a[][#{brackets}=2").must_equal({"a" => [{"b" => "1"}, {"[#{brackets}" => "2"}]})
    query_parser.parse_nested_query("a[][b]=1&a[]#{brackets}=2").must_equal({"a" => [{"b" => "1"}, {brackets => "2"}]})
    brackets = "]" * 1_000_000
    query_parser.parse_nested_query("a[][b]=1&a[]#{brackets}=2").must_equal({"a" => [{"b" => "1"}, {brackets => "2"}]})
    query_parser.parse_nested_query("a[]#{brackets}=1&a[]#{brackets}=2").must_equal({"a" => [{brackets => "1"}, {brackets => "2"}]})
  end

  it "does not use quantified separator patterns" do
    # GHSA-f7cc-57h7-qrcg: a separator pattern such as /& */n allocates
    # backtracking state for every character matched by the quantifier.
    Rack::QueryParser::DEFAULT_SEP.must_be_kind_of String
    Rack::QueryParser::COMMON_SEP.each_value do |sep|
      sep.source.wont_match(/[*+?{]/) if sep.is_a?(Regexp)
    end
  end
end
