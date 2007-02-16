require 'rack/utils'

context "Rack::Utils" do
  specify "should escape correctly" do
    Rack::Utils.escape("fo<o>bar").should.equal "fo%3Co%3Ebar"
    Rack::Utils.escape("a space").should.equal "a+space"
    Rack::Utils.escape("q1!2\"'w$5&7/z8)?\\").
      should.equal "q1%212%22%27w%245%267%2Fz8%29%3F%5C"
  end

  specify "should unescape correctly" do
    Rack::Utils.unescape("fo%3Co%3Ebar").should.equal "fo<o>bar"
    Rack::Utils.unescape("a+space").should.equal "a space"
    Rack::Utils.unescape("a%20space").should.equal "a space"
    Rack::Utils.unescape("q1%212%22%27w%245%267%2Fz8%29%3F%5C").
      should.equal "q1!2\"'w$5&7/z8)?\\"
  end

  specify "should parse queries correctly" do
    Rack::Utils.parse_query("foo=bar").should.equal "foo" => "bar"
    Rack::Utils.parse_query("foo=bar&foo=quux").
      should.equal "foo" => ["bar", "quux"]
    Rack::Utils.parse_query("my+weird+field=q1%212%22%27w%245%267%2Fz8%29%3F").
      should.equal "my weird field" => "q1!2\"'w$5&7/z8)?"
  end
end

context "Rack::Utils::HeaderHash" do
  specify "should capitalize on all accesses" do
    h = Rack::Utils::HeaderHash.new("foo" => "bar")
    h["foo"].should.equal "bar"
    h["Foo"].should.equal "bar"
    h["FOO"].should.equal "bar"

    h.to_hash.should.equal "Foo" => "bar"

    h["bar-zzle"] = "quux"

    h.to_hash.should.equal "Foo" => "bar", "Bar-Zzle" => "quux"
  end

  specify "should capitalize correctly" do
    h = Rack::Utils::HeaderHash.new

    h.capitalize("foo").should.equal "Foo"
    h.capitalize("foo-bar").should.equal "Foo-Bar"
    h.capitalize("foo_bar").should.equal "Foo_Bar"
    h.capitalize("foo bar").should.equal "Foo Bar"
    h.capitalize("foo-bar-quux").should.equal "Foo-Bar-Quux"
    h.capitalize("foo-bar-2quux").should.equal "Foo-Bar-2quux"
  end

  specify "should be converted to real Hash" do
    h = Rack::Utils::HeaderHash.new("foo" => "bar")
    h.to_hash.should.be.instance_of Hash
  end
end
