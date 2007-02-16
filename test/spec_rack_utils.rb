require 'rack/utils'

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
