# frozen_string_literal: true

require_relative 'helper'

separate_testing do
  require_relative '../lib/rack/query_parser'
end

describe Rack::QueryParser do
  query_parser ||= Rack::QueryParser.make_default(8)

  it "can normalize values with missing values" do
    query_parser.parse_nested_query("a=a").must_equal({"a" => "a"})
    query_parser.parse_nested_query("a=").must_equal({"a" => ""})
    query_parser.parse_nested_query("a").must_equal({"a" => nil})
  end
end
