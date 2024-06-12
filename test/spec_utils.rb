# frozen_string_literal: true

require_relative 'helper'
require 'timeout'

separate_testing do
  require_relative '../lib/rack/utils'
  require_relative '../lib/rack/lint'
  require_relative '../lib/rack/mock_request'
  require_relative '../lib/rack/request'
  require_relative '../lib/rack/content_length'
end

describe Rack::Utils do

  def assert_sets(exp, act)
    exp = Set.new exp.split '&'
    act = Set.new act.split '&'

    assert_equal exp, act
  end

  def assert_query(exp, act)
    assert_sets exp, Rack::Utils.build_query(act)
  end

  def assert_nested_query(exp, act)
    assert_sets exp, Rack::Utils.build_nested_query(act)
  end

  it 'can be mixed in and used' do
    instance = Class.new {
      include Rack::Utils

      public :parse_nested_query
      public :parse_query
    }.new

    assert_equal({ "foo" => "bar" }, instance.parse_nested_query("foo=bar"))
    assert_equal({ "foo" => "bar" }, instance.parse_query("foo=bar"))
  end

  it "round trip binary data" do
    r = [218, 0].pack 'CC'
    z = Rack::Utils.unescape(Rack::Utils.escape(r), Encoding::BINARY)
    r.must_equal z
  end

  it "escape correctly" do
    Rack::Utils.escape("fo<o>bar").must_equal "fo%3Co%3Ebar"
    Rack::Utils.escape("a space").must_equal "a+space"
    Rack::Utils.escape("q1!2\"'w$5&7/z8)?\\").
      must_equal "q1%212%22%27w%245%267%2Fz8%29%3F%5C"
  end

  it "escape correctly for multibyte characters" do
    matz_name = "\xE3\x81\xBE\xE3\x81\xA4\xE3\x82\x82\xE3\x81\xA8".unpack("a*")[0] # Matsumoto
    matz_name.force_encoding(Encoding::UTF_8)
    Rack::Utils.escape(matz_name).must_equal '%E3%81%BE%E3%81%A4%E3%82%82%E3%81%A8'
    matz_name_sep = "\xE3\x81\xBE\xE3\x81\xA4 \xE3\x82\x82\xE3\x81\xA8".unpack("a*")[0] # Matsu moto
    matz_name_sep.force_encoding("UTF-8") if matz_name_sep.respond_to? :force_encoding
    Rack::Utils.escape(matz_name_sep).must_equal '%E3%81%BE%E3%81%A4+%E3%82%82%E3%81%A8'
  end

  it "escape objects that responds to to_s" do
    Rack::Utils.escape(:id).must_equal "id"
  end

  it "escape non-UTF8 strings" do
    Rack::Utils.escape("ø".encode("ISO-8859-1")).must_equal "%F8"
  end

  it "not hang on escaping long strings that end in % (http://redmine.ruby-lang.org/issues/5149)" do
    Timeout.timeout(1) do
      lambda {
        URI.decode_www_form_component "A string that causes catastrophic backtracking as it gets longer %"
      }.must_raise ArgumentError
    end
  end

  it "escape path spaces with %20" do
    Rack::Utils.escape_path("foo bar").must_equal "foo%20bar"
  end

  it "unescape correctly" do
    Rack::Utils.unescape("fo%3Co%3Ebar").must_equal "fo<o>bar"
    Rack::Utils.unescape("a+space").must_equal "a space"
    Rack::Utils.unescape("a%20space").must_equal "a space"
    Rack::Utils.unescape("q1%212%22%27w%245%267%2Fz8%29%3F%5C").
      must_equal "q1!2\"'w$5&7/z8)?\\"
  end

  it "parse query strings correctly" do
    Rack::Utils.parse_query("foo=bar").
      must_equal "foo" => "bar"
    Rack::Utils.parse_query("foo=\"bar\"").
      must_equal "foo" => "\"bar\""
    Rack::Utils.parse_query("foo=bar&foo=quux").
      must_equal "foo" => ["bar", "quux"]
    Rack::Utils.parse_query("foo=1&bar=2").
      must_equal "foo" => "1", "bar" => "2"
    Rack::Utils.parse_query("my+weird+field=q1%212%22%27w%245%267%2Fz8%29%3F").
      must_equal "my weird field" => "q1!2\"'w$5&7/z8)?"
    Rack::Utils.parse_query("foo%3Dbaz=bar").must_equal "foo=baz" => "bar"
    Rack::Utils.parse_query("=").must_equal "" => ""
    Rack::Utils.parse_query("=value").must_equal "" => "value"
    Rack::Utils.parse_query("key=").must_equal "key" => ""
    Rack::Utils.parse_query("&key&").must_equal "key" => nil
    Rack::Utils.parse_query(";key;", ";,").must_equal "key" => nil
    Rack::Utils.parse_query(",key,", ";,").must_equal "key" => nil
    Rack::Utils.parse_query(";foo=bar,;", ";,").must_equal "foo" => "bar"
    Rack::Utils.parse_query(",foo=bar;,", ";,").must_equal "foo" => "bar"
  end

  it "parse query strings correctly using arrays" do
    Rack::Utils.parse_query("a[]=1").must_equal "a[]" => "1"
    Rack::Utils.parse_query("a[]=1&a[]=2").must_equal "a[]" => ["1", "2"]
    Rack::Utils.parse_query("a[]=1&a[]=2&a[]=3").must_equal "a[]" => ["1", "2", "3"]
  end

  it "not create infinite loops with cycle structures" do
    params = Rack::Utils::KeySpaceConstrainedParams.new
    params['foo'] = params
    h = params.to_params_hash
    h['foo'].to_s.must_equal h['foo']['foo'].to_s
  end

  it "parse nil as an empty query string" do
    Rack::Utils.parse_nested_query(nil).must_equal({})
  end

  it "raise an exception if the params are too deep" do
    len = Rack::Utils.param_depth_limit

    lambda {
      Rack::Utils.parse_nested_query("foo#{"[a]" * len}=bar")
    }.must_raise(Rack::QueryParser::ParamsTooDeepError)

    Rack::Utils.parse_nested_query("foo#{"[a]" * (len - 1)}=bar")
  end

  it "parse nested query strings correctly" do
    Rack::Utils.parse_nested_query("foo").
      must_equal "foo" => nil
    Rack::Utils.parse_nested_query("foo=").
      must_equal "foo" => ""
    Rack::Utils.parse_nested_query("foo=bar").
      must_equal "foo" => "bar"
    Rack::Utils.parse_nested_query("foo=\"bar\"").
      must_equal "foo" => "\"bar\""

    Rack::Utils.parse_nested_query("foo=bar&foo=quux").
      must_equal "foo" => "quux"
    Rack::Utils.parse_nested_query("foo&foo=").
      must_equal "foo" => ""
    Rack::Utils.parse_nested_query("foo=1&bar=2").
      must_equal "foo" => "1", "bar" => "2"
    Rack::Utils.parse_nested_query("&foo=1&&bar=2").
      must_equal "foo" => "1", "bar" => "2"
    Rack::Utils.parse_nested_query("foo&bar=").
      must_equal "foo" => nil, "bar" => ""
    Rack::Utils.parse_nested_query("foo=bar&baz=").
      must_equal "foo" => "bar", "baz" => ""
    Rack::Utils.parse_nested_query("my+weird+field=q1%212%22%27w%245%267%2Fz8%29%3F").
      must_equal "my weird field" => "q1!2\"'w$5&7/z8)?"

    Rack::Utils.parse_nested_query("a=b&pid%3D1234=1023").
      must_equal "pid=1234" => "1023", "a" => "b"

    Rack::Utils.parse_nested_query("foo[]").
      must_equal "foo" => [nil]
    Rack::Utils.parse_nested_query("foo[]=").
      must_equal "foo" => [""]
    Rack::Utils.parse_nested_query("foo[]=bar").
      must_equal "foo" => ["bar"]
    Rack::Utils.parse_nested_query("foo[]=bar&foo").
      must_equal "foo" => nil
    Rack::Utils.parse_nested_query("foo[]=bar&foo[").
      must_equal "foo" => ["bar"], "foo[" => nil
    Rack::Utils.parse_nested_query("foo[]=bar&foo[=baz").
      must_equal "foo" => ["bar"], "foo[" => "baz"
    Rack::Utils.parse_nested_query("foo[]=bar&foo[]").
      must_equal "foo" => ["bar", nil]
    Rack::Utils.parse_nested_query("foo[]=bar&foo[]=").
      must_equal "foo" => ["bar", ""]

    Rack::Utils.parse_nested_query("foo[]=1&foo[]=2").
      must_equal "foo" => ["1", "2"]
    Rack::Utils.parse_nested_query("foo=bar&baz[]=1&baz[]=2&baz[]=3").
      must_equal "foo" => "bar", "baz" => ["1", "2", "3"]
    Rack::Utils.parse_nested_query("foo[]=bar&baz[]=1&baz[]=2&baz[]=3").
      must_equal "foo" => ["bar"], "baz" => ["1", "2", "3"]

    Rack::Utils.parse_nested_query("x[y][z]").
      must_equal "x" => { "y" => { "z" => nil } }
    Rack::Utils.parse_nested_query("x[y][z]=1").
      must_equal "x" => { "y" => { "z" => "1" } }
    Rack::Utils.parse_nested_query("x[y][z][]=1").
      must_equal "x" => { "y" => { "z" => ["1"] } }
    Rack::Utils.parse_nested_query("x[y][z]=1&x[y][z]=2").
      must_equal "x" => { "y" => { "z" => "2" } }
    Rack::Utils.parse_nested_query("x[y][z][]=1&x[y][z][]=2").
      must_equal "x" => { "y" => { "z" => ["1", "2"] } }

    Rack::Utils.parse_nested_query("x[y][][z]=1").
      must_equal "x" => { "y" => [{ "z" => "1" }] }
    Rack::Utils.parse_nested_query("x[y][][z][]=1").
      must_equal "x" => { "y" => [{ "z" => ["1"] }] }
    Rack::Utils.parse_nested_query("x[y][][z]=1&x[y][][w]=2").
      must_equal "x" => { "y" => [{ "z" => "1", "w" => "2" }] }

    Rack::Utils.parse_nested_query("x[y][][v][w]=1").
      must_equal "x" => { "y" => [{ "v" => { "w" => "1" } }] }
    Rack::Utils.parse_nested_query("x[y][][z]=1&x[y][][v][w]=2").
      must_equal "x" => { "y" => [{ "z" => "1", "v" => { "w" => "2" } }] }

    Rack::Utils.parse_nested_query("x[y][][z]=1&x[y][][z]=2").
      must_equal "x" => { "y" => [{ "z" => "1" }, { "z" => "2" }] }
    Rack::Utils.parse_nested_query("x[y][][z]=1&x[y][][w]=a&x[y][][z]=2&x[y][][w]=3").
      must_equal "x" => { "y" => [{ "z" => "1", "w" => "a" }, { "z" => "2", "w" => "3" }] }

    Rack::Utils.parse_nested_query("x[][y]=1&x[][z][w]=a&x[][y]=2&x[][z][w]=b").
      must_equal "x" => [{ "y" => "1", "z" => { "w" => "a" } }, { "y" => "2", "z" => { "w" => "b" } }]
    Rack::Utils.parse_nested_query("x[][z][w]=a&x[][y]=1&x[][z][w]=b&x[][y]=2").
      must_equal "x" => [{ "y" => "1", "z" => { "w" => "a" } }, { "y" => "2", "z" => { "w" => "b" } }]

    Rack::Utils.parse_nested_query("data[books][][data][page]=1&data[books][][data][page]=2").
      must_equal "data" => { "books" => [{ "data" => { "page" => "1" } }, { "data" => { "page" => "2" } }] }

    lambda { Rack::Utils.parse_nested_query("x[y]=1&x[y]z=2") }.
      must_raise(Rack::Utils::ParameterTypeError).
      message.must_equal "expected Hash (got String) for param `y'"

    lambda { Rack::Utils.parse_nested_query("x[y]=1&x[]=1") }.
      must_raise(Rack::Utils::ParameterTypeError).
      message.must_match(/expected Array \(got [^)]*\) for param `x'/)

    lambda { Rack::Utils.parse_nested_query("x[y]=1&x[y][][w]=2") }.
      must_raise(Rack::Utils::ParameterTypeError).
      message.must_equal "expected Array (got String) for param `y'"
  end

  it "can parse a query string with a key that has invalid UTF-8 encoded bytes" do
    Rack::Utils.parse_nested_query("foo%81E=1").must_equal "foo\x81E"=>"1"
  end

  it "only moves to a new array when the full key has been seen" do
    Rack::Utils.parse_nested_query("x[][y][][z]=1&x[][y][][w]=2").
      must_equal "x" => [{ "y" => [{ "z" => "1", "w" => "2" }] }]

    Rack::Utils.parse_nested_query(
      "x[][id]=1&x[][y][a]=5&x[][y][b]=7&x[][z][id]=3&x[][z][w]=0&x[][id]=2&x[][y][a]=6&x[][y][b]=8&x[][z][id]=4&x[][z][w]=0"
    ).must_equal "x" => [
        { "id" => "1", "y" => { "a" => "5", "b" => "7" }, "z" => { "id" => "3", "w" => "0" } },
        { "id" => "2", "y" => { "a" => "6", "b" => "8" }, "z" => { "id" => "4", "w" => "0" } },
      ]
  end

  it "handles unexpected use of [ and ] in parameter keys as normal characters" do
    Rack::Utils.parse_nested_query("[]=1&[a]=2&b[=3&c]=4").
      must_equal "[]" => "1", "[a]" => "2", "b[" => "3", "c]" => "4"

    Rack::Utils.parse_nested_query("d[[]=5&e][]=6&f[[]]=7").
      must_equal "d" => {"[" => "5"}, "e]" => ["6"], "f" => { "[" => { "]" => "7" } }

    Rack::Utils.parse_nested_query("g[h]i=8&j[k]l[m]=9").
      must_equal "g" => { "h" => { "i" => "8" } }, "j" => { "k" => { "l[m]" =>"9" } }

    Rack::Utils.parse_nested_query("l[[[[[[[[]]]]]]]=10").
      must_equal "l"=>{"[[[[[[["=>{"]]]]]]"=>"10"}}
  end

  it "allow setting the params hash class to use for parsing query strings" do
    begin
      default_parser = Rack::Utils.default_query_parser
      param_parser_class = Class.new(Rack::QueryParser::Params) do
        def initialize(*)
          super(){|h, k| h[k.to_s] if k.is_a?(Symbol)}
        end
      end
      Rack::Utils.default_query_parser = Rack::QueryParser.new(param_parser_class, 100)
      h1 = Rack::Utils.parse_query(",foo=bar;,", ";,")
      h1[:foo].must_equal "bar"
      h2 = Rack::Utils.parse_nested_query("x[y][][z]=1&x[y][][w]=2")
      h2[:x][:y][0][:z].must_equal "1"
      h3 = Rack::Utils.parse_nested_query("")
      h3.merge(h1)[:foo].must_equal "bar"
    ensure
      Rack::Utils.default_query_parser = default_parser
    end
  end

  it "build query strings correctly" do
    assert_query "foo=bar", "foo" => "bar"
    assert_query "foo=bar&foo=quux", "foo" => ["bar", "quux"]
    assert_query "foo=1&bar=2", "foo" => "1", "bar" => "2"
    assert_query("my+weird+field=q1%212%22%27w%245%267%2Fz8%29%3F",
                 "my weird field" => "q1!2\"'w$5&7/z8)?")
  end

  it "build nested query strings correctly" do
    Rack::Utils.build_nested_query("foo" => nil).must_equal "foo"
    Rack::Utils.build_nested_query("foo" => "").must_equal "foo="
    Rack::Utils.build_nested_query("foo" => "bar").must_equal "foo=bar"

    assert_nested_query("foo=1&bar=2",
                        "foo" => "1", "bar" => "2")
    assert_nested_query("foo=1&bar=2",
                        "foo" => 1, "bar" => 2)
    assert_nested_query("my+weird+field=q1%212%22%27w%245%267%2Fz8%29%3F",
                        "my weird field" => "q1!2\"'w$5&7/z8)?")

    Rack::Utils.build_nested_query("foo" => [nil]).must_equal "foo%5B%5D"
    Rack::Utils.build_nested_query("foo" => [""]).must_equal "foo%5B%5D="
    Rack::Utils.build_nested_query("foo" => ["bar"]).must_equal "foo%5B%5D=bar"
    Rack::Utils.build_nested_query('foo' => []).must_equal ''
    Rack::Utils.build_nested_query('foo' => {}).must_equal ''
    Rack::Utils.build_nested_query('foo' => 'bar', 'baz' => []).must_equal 'foo=bar'
    Rack::Utils.build_nested_query('foo' => 'bar', 'baz' => {}).must_equal 'foo=bar'

    Rack::Utils.build_nested_query('foo' => nil, 'bar' => '').
      must_equal 'foo&bar='
    Rack::Utils.build_nested_query('foo' => 'bar', 'baz' => '').
      must_equal 'foo=bar&baz='
    Rack::Utils.build_nested_query('foo' => ['1', '2']).
      must_equal 'foo%5B%5D=1&foo%5B%5D=2'
    Rack::Utils.build_nested_query('foo' => 'bar', 'baz' => ['1', '2', '3']).
      must_equal 'foo=bar&baz%5B%5D=1&baz%5B%5D=2&baz%5B%5D=3'
    Rack::Utils.build_nested_query('foo' => ['bar'], 'baz' => ['1', '2', '3']).
      must_equal 'foo%5B%5D=bar&baz%5B%5D=1&baz%5B%5D=2&baz%5B%5D=3'
    Rack::Utils.build_nested_query('foo' => ['bar'], 'baz' => ['1', '2', '3']).
      must_equal 'foo%5B%5D=bar&baz%5B%5D=1&baz%5B%5D=2&baz%5B%5D=3'
    Rack::Utils.build_nested_query('x' => { 'y' => { 'z' => '1' } }).
      must_equal 'x%5By%5D%5Bz%5D=1'
    Rack::Utils.build_nested_query('x' => { 'y' => { 'z' => ['1'] } }).
      must_equal 'x%5By%5D%5Bz%5D%5B%5D=1'
    Rack::Utils.build_nested_query('x' => { 'y' => { 'z' => ['1', '2'] } }).
      must_equal 'x%5By%5D%5Bz%5D%5B%5D=1&x%5By%5D%5Bz%5D%5B%5D=2'
    Rack::Utils.build_nested_query('x' => { 'y' => [{ 'z' => '1' }] }).
      must_equal 'x%5By%5D%5B%5D%5Bz%5D=1'
    Rack::Utils.build_nested_query('x' => { 'y' => [{ 'z' => ['1'] }] }).
      must_equal 'x%5By%5D%5B%5D%5Bz%5D%5B%5D=1'
    Rack::Utils.build_nested_query('x' => { 'y' => [{ 'z' => '1', 'w' => '2' }] }).
      must_equal 'x%5By%5D%5B%5D%5Bz%5D=1&x%5By%5D%5B%5D%5Bw%5D=2'
    Rack::Utils.build_nested_query('x' => { 'y' => [{ 'v' => { 'w' => '1' } }] }).
      must_equal 'x%5By%5D%5B%5D%5Bv%5D%5Bw%5D=1'
    Rack::Utils.build_nested_query('x' => { 'y' => [{ 'z' => '1', 'v' => { 'w' => '2' } }] }).
      must_equal 'x%5By%5D%5B%5D%5Bz%5D=1&x%5By%5D%5B%5D%5Bv%5D%5Bw%5D=2'
    Rack::Utils.build_nested_query('x' => { 'y' => [{ 'z' => '1' }, { 'z' => '2' }] }).
      must_equal 'x%5By%5D%5B%5D%5Bz%5D=1&x%5By%5D%5B%5D%5Bz%5D=2'
    Rack::Utils.build_nested_query('x' => { 'y' => [{ 'z' => '1', 'w' => 'a' }, { 'z' => '2', 'w' => '3' }] }).
      must_equal 'x%5By%5D%5B%5D%5Bz%5D=1&x%5By%5D%5B%5D%5Bw%5D=a&x%5By%5D%5B%5D%5Bz%5D=2&x%5By%5D%5B%5D%5Bw%5D=3'
    Rack::Utils.build_nested_query({ "foo" => ["1", ["2"]] }).
      must_equal 'foo%5B%5D=1&foo%5B%5D%5B%5D=2'

    # A nested hash is the same as string keys with brackets.
    Rack::Utils.build_nested_query('foo' => { 'bar' => 'baz' }).
      must_equal Rack::Utils.build_nested_query('foo[bar]' => 'baz')

    lambda { Rack::Utils.build_nested_query("foo=bar") }.
      must_raise(ArgumentError).
      message.must_equal "value must be a Hash"
  end

  it 'performs the inverse function of #parse_nested_query' do
    [{ "bar" => "" },
      { "foo" => "bar", "baz" => "" },
      { "foo" => ["1", "2"] },
      { "foo" => "bar", "baz" => ["1", "2", "3"] },
      { "foo" => ["bar"], "baz" => ["1", "2", "3"] },
      { "foo" => ["1", "2"] },
      { "foo" => "bar", "baz" => ["1", "2", "3"] },
      { "x" => { "y" => { "z" => "1" } } },
      { "x" => { "y" => { "z" => ["1"] } } },
      { "x" => { "y" => { "z" => ["1", "2"] } } },
      { "x" => { "y" => [{ "z" => "1" }] } },
      { "x" => { "y" => [{ "z" => ["1"] }] } },
      { "x" => { "y" => [{ "z" => "1", "w" => "2" }] } },
      { "x" => { "y" => [{ "v" => { "w" => "1" } }] } },
      { "x" => { "y" => [{ "z" => "1", "v" => { "w" => "2" } }] } },
      { "x" => { "y" => [{ "z" => "1" }, { "z" => "2" }] } },
      { "x" => { "y" => [{ "z" => "1", "w" => "a" }, { "z" => "2", "w" => "3" }] } },
      { "foo" => ["1", ["2"]] },
    ].each { |params|
      qs = Rack::Utils.build_nested_query(params)
      Rack::Utils.parse_nested_query(qs).must_equal params
    }

    lambda { Rack::Utils.build_nested_query("foo=bar") }.
      must_raise(ArgumentError).
      message.must_equal "value must be a Hash"
  end

  it "parse query strings that have a non-existent value" do
    key = "post/2011/08/27/Deux-%22rat%C3%A9s%22-de-l-Universit"
    Rack::Utils.parse_query(key).must_equal Rack::Utils.unescape(key) => nil
  end

  it "build query strings without = with non-existent values" do
    key = "post/2011/08/27/Deux-%22rat%C3%A9s%22-de-l-Universit"
    key = Rack::Utils.unescape(key)
    Rack::Utils.build_query(key => nil).must_equal Rack::Utils.escape(key)
  end

  it "parse q-values" do
    # XXX handle accept-extension
    Rack::Utils.q_values("foo;q=0.5,bar,baz;q=0.9").must_equal [
      [ 'foo', 0.5 ],
      [ 'bar', 1.0 ],
      [ 'baz', 0.9 ]
    ]
  end

  it "parses RFC 7239 Forwarded header" do
    Rack::Utils.forwarded_values('for=3.4.5.6').must_equal({
      for: [ '3.4.5.6' ],
    })

    Rack::Utils.forwarded_values(';;;for=3.4.5.6,,').must_equal({
      for: [ '3.4.5.6' ],
    })

    Rack::Utils.forwarded_values('for=3.4.5.6').must_equal({
      for: [ '3.4.5.6' ],
    })

    Rack::Utils.forwarded_values('for =  3.4.5.6').must_equal({
      for: [ '3.4.5.6' ],
    })

    Rack::Utils.forwarded_values('for="3.4.5.6"').must_equal({
      for: [ '3.4.5.6' ],
    })

    Rack::Utils.forwarded_values('for=3.4.5.6;proto=https').must_equal({
      for: [ '3.4.5.6' ],
      proto: [ 'https' ]
    })

    Rack::Utils.forwarded_values('for=3.4.5.6; proto=http, proto=https').must_equal({
      for: [ '3.4.5.6' ],
      proto: [ 'http', 'https' ]
    })

    Rack::Utils.forwarded_values('for=3.4.5.6; proto=http, proto=https; for=1.2.3.4').must_equal({
      for: [ '3.4.5.6', '1.2.3.4' ],
      proto: [ 'http', 'https' ]
    })

    Rack::Utils.forwarded_values('for=3.4.5.6; foo=bar').must_be_nil
  end

  it "select best quality match" do
    Rack::Utils.best_q_match("text/html", %w[text/html]).must_equal "text/html"

    # More specific matches are preferred
    Rack::Utils.best_q_match("text/*;q=0.5,text/html;q=1.0", %w[text/html]).must_equal "text/html"

    # Higher quality matches are preferred
    Rack::Utils.best_q_match("text/*;q=0.5,text/plain;q=1.0", %w[text/plain text/html]).must_equal "text/plain"

    # Respect requested content type
    Rack::Utils.best_q_match("application/json", %w[application/vnd.lotus-1-2-3 application/json]).must_equal "application/json"

    # All else equal, the available mimes are preferred in order
    Rack::Utils.best_q_match("text/*", %w[text/html text/plain]).must_equal "text/html"
    Rack::Utils.best_q_match("text/plain,text/html", %w[text/html text/plain]).must_equal "text/html"

    # When there are no matches, return nil:
    Rack::Utils.best_q_match("application/json", %w[text/html text/plain]).must_be_nil
  end

  it "escape html entities [&><'\"/]" do
    Rack::Utils.escape_html("foo").must_equal "foo"
    Rack::Utils.escape_html("f&o").must_equal "f&amp;o"
    Rack::Utils.escape_html("f<o").must_equal "f&lt;o"
    Rack::Utils.escape_html("f>o").must_equal "f&gt;o"
    Rack::Utils.escape_html("f'o").must_equal "f&#39;o"
    Rack::Utils.escape_html('f"o').must_equal "f&quot;o"
    Rack::Utils.escape_html("<foo></foo>").must_equal "&lt;foo&gt;&lt;/foo&gt;"
    Rack::Utils.escape_html("\300<").must_equal "\300&lt;"
  end

  it "escape html entities in unicode strings" do
      # the following will cause warnings if the regex is poorly encoded:
    Rack::Utils.escape_html("☃").must_equal "☃"
  end

  it 'escape_html handles non-strings' do
    Rack::Utils.escape_html(nil).must_equal ""
    Rack::Utils.escape_html(123).must_equal "123"
  end

  it "figure out which encodings are acceptable" do
    helper = lambda do |a, b|
      Rack::Request.new(Rack::MockRequest.env_for("", "HTTP_ACCEPT_ENCODING" => a))
      Rack::Utils.select_best_encoding(a, b)
    end

    helper.call(%w(), [["x", 1]]).must_be_nil
    helper.call(%w(identity), [["identity", 0.0]]).must_be_nil
    helper.call(%w(identity), [["*", 0.0]]).must_be_nil

    helper.call(%w(identity), [["compress", 1.0], ["gzip", 1.0]]).must_equal "identity"

    helper.call(%w(compress gzip identity), [["compress", 1.0], ["gzip", 1.0]]).must_equal "compress"
    helper.call(%w(compress gzip identity), [["compress", 0.5], ["gzip", 1.0]]).must_equal "gzip"
    helper.call(%w(compress gzip identity), [["gzip", 1.0], ["compress", 1.0]]).must_equal "compress"

    helper.call(%w(foo bar identity), []).must_equal "identity"
    helper.call(%w(foo bar identity), [["*", 1.0]]).must_equal "foo"
    helper.call(%w(foo bar identity), [["*", 1.0], ["foo", 0.9]]).must_equal "bar"

    helper.call(%w(foo bar identity), [["foo", 0], ["bar", 0]]).must_equal "identity"
    helper.call(%w(foo bar baz identity), [["*", 0], ["identity", 0.1]]).must_equal "identity"
  end

  it "should perform constant time string comparison" do
    Rack::Utils.secure_compare('a', 'a').must_equal true
    Rack::Utils.secure_compare('a', 'b').must_equal false
    Rack::Utils.secure_compare('a', 'bb').must_equal false
  end

  it "return status code for integer" do
    Rack::Utils.status_code(200).must_equal 200
  end

  it "return status code for string" do
    Rack::Utils.status_code("200").must_equal 200
  end

  it "return status code for symbol" do
    Rack::Utils.status_code(:ok).must_equal 200
  end

  it "return status code and give deprecation warning for obsolete symbols" do
    replaced_statuses = {
      payload_too_large: {status_code: 413, standard_symbol: :content_too_large},
      unprocessable_entity: {status_code: 422, standard_symbol: :unprocessable_content}
    }
    dropped_statuses = {bandwidth_limit_exceeded: 509, not_extended: 510}

    capture_warnings(Rack::Utils) do |warnings|
      replaced_statuses.each do |symbol, value_hash|
        Rack::Utils.status_code(symbol).must_equal value_hash[:status_code]
        warnings.pop.must_equal ["Status code #{symbol.inspect} is deprecated and will be removed in a future version of Rack. Please use #{value_hash[:standard_symbol].inspect} instead.", { uplevel: 3 }]
      end

      dropped_statuses.each do |symbol, code|
        Rack::Utils.status_code(symbol).must_equal code
        warnings.pop.must_equal ["Status code #{symbol.inspect} is deprecated and will be removed in a future version of Rack.", { uplevel: 3 }]
      end
    end
  end

  it "raise an error for an invalid symbol" do
    error = assert_raises(ArgumentError) do
      Rack::Utils.status_code(:foobar)
    end
    error.message.must_equal "Unrecognized status code :foobar"
  end

  it "return rfc2822 format from rfc2822 helper" do
    Rack::Utils.rfc2822(Time.at(0).gmtime).must_equal "Thu, 01 Jan 1970 00:00:00 -0000"
  end

  it "clean directory traversal" do
    Rack::Utils.clean_path_info("/cgi/../cgi/test").must_equal "/cgi/test"
    Rack::Utils.clean_path_info(".").must_be_empty
    Rack::Utils.clean_path_info("test/..").must_be_empty
  end

  it "clean unsafe directory traversal to safe path" do
    Rack::Utils.clean_path_info("/../README.rdoc").must_equal "/README.rdoc"
    Rack::Utils.clean_path_info("../test/spec_utils.rb").must_equal "test/spec_utils.rb"
  end

  it "not clean directory traversal with encoded periods" do
    Rack::Utils.clean_path_info("/%2E%2E/README").must_equal "/%2E%2E/README"
  end

  it "clean slash only paths" do
    Rack::Utils.clean_path_info("/").must_equal "/"
  end
end

describe Rack::Utils, "cookies" do
  it "parses cookies" do
    env = Rack::MockRequest.env_for("", "HTTP_COOKIE" => "a=b; ; c=d")
    Rack::Utils.parse_cookies(env).must_equal({ "a" => "b", "c" => "d" })

    env = Rack::MockRequest.env_for("", "HTTP_COOKIE" => "zoo=m")
    Rack::Utils.parse_cookies(env).must_equal({ "zoo" => "m" })

    env = Rack::MockRequest.env_for("", "HTTP_COOKIE" => "foo=%")
    Rack::Utils.parse_cookies(env).must_equal({ "foo" => "%" })

    env = Rack::MockRequest.env_for("", "HTTP_COOKIE" => "foo=bar;foo=car")
    Rack::Utils.parse_cookies(env).must_equal({ "foo" => "bar" })

    env = Rack::MockRequest.env_for("", "HTTP_COOKIE" => "foo=bar;quux=h&m")
    Rack::Utils.parse_cookies(env).must_equal({ "foo" => "bar", "quux" => "h&m" })

    env = Rack::MockRequest.env_for("", "HTTP_COOKIE" => "foo=bar; quux=h&m")
    Rack::Utils.parse_cookies(env).must_equal({ "foo" => "bar", "quux" => "h&m" })

    env = Rack::MockRequest.env_for("", "HTTP_COOKIE" => "foo=bar").freeze
    Rack::Utils.parse_cookies(env).must_equal({ "foo" => "bar" })

    env = Rack::MockRequest.env_for("", "HTTP_COOKIE" => "%66oo=baz;foo=bar")
    cookies = Rack::Utils.parse_cookies(env)
    cookies.must_equal({ "%66oo" => "baz", "foo" => "bar" })
  end

  it "generates appropriate cookie header value" do
    Rack::Utils.set_cookie_header('name', 'value').must_equal 'name=value'
    Rack::Utils.set_cookie_header('name', %w[value]).must_equal 'name=value'
    Rack::Utils.set_cookie_header('name', %w[va ue]).must_equal 'name=va&ue'
  end

  it "sets and deletes cookies in header hash" do
    headers = {}
    Rack::Utils.set_cookie_header!(headers, 'name', 'value')
    headers['set-cookie'].must_equal 'name=value'
    Rack::Utils.set_cookie_header!(headers, 'name2', 'value2')
    headers['set-cookie'].must_equal ['name=value', 'name2=value2']
    Rack::Utils.set_cookie_header!(headers, 'name2', 'value3')
    headers['set-cookie'].must_equal ['name=value', 'name2=value2', 'name2=value3']
  end

  it "raises an error if the cookie key is invalid" do
    lambda do
      Rack::Utils.set_cookie_header('na e', 'value')
    end.must_raise(ArgumentError, /invalid cookie key/)
  end

  it "sets partitioned cookie attribute" do
    Rack::Utils.set_cookie_header('name', {value: 'value', partitioned: true}).must_equal 'name=value; partitioned'
  end

  it "deletes cookies in header field" do
    header = []

    Rack::Utils.delete_set_cookie_header!(header, 'name2')
    header.must_equal [
      "name2=; max-age=0; expires=Thu, 01 Jan 1970 00:00:00 GMT"
    ]

    Rack::Utils.delete_set_cookie_header!(header, 'name')
    header.must_equal [
      "name2=; max-age=0; expires=Thu, 01 Jan 1970 00:00:00 GMT",
      "name=; max-age=0; expires=Thu, 01 Jan 1970 00:00:00 GMT"
    ]
  end

  it "deletes cookies in header field with domain" do
    header = []

    Rack::Utils.delete_set_cookie_header!(header, 'name', {domain: "mydomain.com"})
    header.must_equal [
      "name=; domain=mydomain.com; max-age=0; expires=Thu, 01 Jan 1970 00:00:00 GMT"
    ]
  end

  it "deletes cookies in header field with path" do
    header = []

    Rack::Utils.delete_set_cookie_header!(header, 'name', {path: "/a/b"})
    header.must_equal [
      "name=; path=/a/b; max-age=0; expires=Thu, 01 Jan 1970 00:00:00 GMT"
    ]
  end

  it "sets and deletes cookies in header hash" do
    header = { 'set-cookie' => nil }
    Rack::Utils.delete_cookie_header!(header, 'name').must_be_nil
    header['set-cookie'].must_equal "name=; max-age=0; expires=Thu, 01 Jan 1970 00:00:00 GMT"

    header = { 'set-cookie' => nil }
    Rack::Utils.delete_cookie_header!(header, 'name').must_be_nil
    header['set-cookie'].must_equal "name=; max-age=0; expires=Thu, 01 Jan 1970 00:00:00 GMT"
  end
end

describe Rack::Utils, "get_byte_ranges" do
  it "returns an empty list if the sum of the ranges is too large" do
    assert_equal [], Rack::Utils.byte_ranges({ "HTTP_RANGE" => "bytes=0-20,0-500" }, 500)
  end

  it "parse simple byte ranges from env" do
    Rack::Utils.byte_ranges({ "HTTP_RANGE" => "bytes=123-456" }, 500).must_equal [(123..456)]
  end

  it "ignore missing or syntactically invalid byte ranges" do
    Rack::Utils.get_byte_ranges(nil, 500).must_be_nil
    Rack::Utils.get_byte_ranges("foobar", 500).must_be_nil
    Rack::Utils.get_byte_ranges("furlongs=123-456", 500).must_be_nil
    Rack::Utils.get_byte_ranges("bytes=", 500).must_be_nil
    Rack::Utils.get_byte_ranges("bytes=-", 500).must_be_nil
    Rack::Utils.get_byte_ranges("bytes=123,456", 500).must_be_nil
    # A range of non-positive length is syntactically invalid and ignored:
    Rack::Utils.get_byte_ranges("bytes=456-123", 500).must_be_nil
    Rack::Utils.get_byte_ranges("bytes=456-455", 500).must_be_nil
  end

  it "parse simple byte ranges" do
    Rack::Utils.get_byte_ranges("bytes=123-456", 500).must_equal [(123..456)]
    Rack::Utils.get_byte_ranges("bytes=123-", 500).must_equal [(123..499)]
    Rack::Utils.get_byte_ranges("bytes=-100", 500).must_equal [(400..499)]
    Rack::Utils.get_byte_ranges("bytes=0-0", 500).must_equal [(0..0)]
    Rack::Utils.get_byte_ranges("bytes=499-499", 500).must_equal [(499..499)]
  end

  it "parse several byte ranges" do
    Rack::Utils.get_byte_ranges("bytes=500-600,601-999", 1000).must_equal [(500..600), (601..999)]
  end

  it "truncate byte ranges" do
    Rack::Utils.get_byte_ranges("bytes=123-999", 500).must_equal [(123..499)]
    Rack::Utils.get_byte_ranges("bytes=600-999", 500).must_equal []
    Rack::Utils.get_byte_ranges("bytes=-999", 500).must_equal [(0..499)]
  end

  it "ignore unsatisfiable byte ranges" do
    Rack::Utils.get_byte_ranges("bytes=500-501", 500).must_equal []
    Rack::Utils.get_byte_ranges("bytes=500-", 500).must_equal []
    Rack::Utils.get_byte_ranges("bytes=999-", 500).must_equal []
    Rack::Utils.get_byte_ranges("bytes=-0", 500).must_equal []
  end

  it "handle byte ranges of empty files" do
    Rack::Utils.get_byte_ranges("bytes=123-456", 0).must_be_nil
    Rack::Utils.get_byte_ranges("bytes=0-", 0).must_be_nil
    Rack::Utils.get_byte_ranges("bytes=-100", 0).must_be_nil
    Rack::Utils.get_byte_ranges("bytes=0-0", 0).must_be_nil
    Rack::Utils.get_byte_ranges("bytes=-0", 0).must_be_nil
  end
end

describe Rack::Utils::Context do
  class ContextTest
    attr_reader :app
    def initialize(app); @app = app; end
    def call(env); context env; end
    def context(env, app = @app); app.call(env); end
  end
  test_target1 = proc{|e| e.to_s + ' world' }
  test_target2 = proc{|e| e.to_i + 2 }
  test_target3 = proc{|e| nil }
  test_target4 = proc{|e| [200, { 'content-type' => 'text/plain', 'content-length' => '0' }, ['']] }
  test_app = ContextTest.new test_target4

  it "set context correctly" do
    test_app.app.must_equal test_target4
    c1 = Rack::Utils::Context.new(test_app, test_target1)
    c1.for.must_equal test_app
    c1.app.must_equal test_target1
    c2 = Rack::Utils::Context.new(test_app, test_target2)
    c2.for.must_equal test_app
    c2.app.must_equal test_target2
  end

  it "alter app on recontexting" do
    c1 = Rack::Utils::Context.new(test_app, test_target1)
    c2 = c1.recontext(test_target2)
    c2.for.must_equal test_app
    c2.app.must_equal test_target2
    c3 = c2.recontext(test_target3)
    c3.for.must_equal test_app
    c3.app.must_equal test_target3
  end

  it "run different apps" do
    c1 = Rack::Utils::Context.new test_app, test_target1
    c2 = c1.recontext test_target2
    c3 = c2.recontext test_target3
    c4 = c3.recontext test_target4
    a4 = Rack::Lint.new c4
    a5 = Rack::Lint.new test_app
    r1 = c1.call('hello')
    r1.must_equal 'hello world'
    r2 = c2.call(2)
    r2.must_equal 4
    r3 = c3.call(:misc_symbol)
    r3.must_be_nil
    r3 = c2.context(:misc_symbol, test_target3)
    r3.must_be_nil
    r4 = Rack::MockRequest.new(a4).get('/')
    r4.status.must_equal 200
    r5 = Rack::MockRequest.new(a5).get('/')
    r5.status.must_equal 200
    r4.body.must_equal r5.body
  end

  it "raises for invalid context" do
    proc do
      Rack::Utils::Context.new(nil, test_target1)
    end.must_raise RuntimeError
  end
end
