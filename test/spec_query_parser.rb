# frozen_string_literal: true

require_relative 'helper'

separate_testing do
  require_relative '../lib/rack/query_parser'
end

describe Rack::QueryParser do
  def query_parser
    @query_parser ||= Rack::QueryParser.new(Rack::QueryParser::Params, 8)
  end

  it "has a default value" do
    assert_equal "", query_parser.missing_value
  end

  it "can normalize values with missing values" do
    query_parser.parse_nested_query("a=a").must_equal({"a" => "a"})
    query_parser.parse_nested_query("a=").must_equal({"a" => ""})
    query_parser.parse_nested_query("a").must_equal({"a" => ""})
  end

  it "can override default missing value" do
    def query_parser.missing_value
      nil
    end

    query_parser.parse_nested_query("a=a").must_equal({"a" => "a"})
    query_parser.parse_nested_query("a=").must_equal({"a" => ""})
    query_parser.parse_nested_query("a").must_equal({"a" => nil})
  end
end
