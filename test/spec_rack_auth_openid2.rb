require 'test/spec'

# requires the ruby-openid gem
require 'rack/auth/openid2'

context "Rack::Auth::OpenID2" do
  OID2 = Rack::Auth::OpenID2
  realm = 'http://path/arf'
  ruri = %w{arf arf/blargh}
  auri = ruri.map{|u|'/'+u}
  furi = auri.map{|u|'http://path'+u}

  specify 'realm uri should be absolute and have a path' do
    lambda{OID2.new('/path')}.
      should.raise ArgumentError
    lambda{OID2.new('http://path')}.
      should.raise ArgumentError
    lambda{OID2.new('http://path/')}.
      should.not.raise
    lambda{OID2.new('http://path/arf')}.
      should.not.raise
  end

  specify 'uri options should be absolute' do
    [:login_good, :login_fail, :login_quit, :return_to].each do |param|
      ruri.each do |uri|
        lambda{OID2.new(realm, {param=>uri})}.
          should.raise ArgumentError
      end
      auri.each do |uri|
        lambda{OID2.new(realm, {param=>uri})}.
          should.raise ArgumentError
      end
      furi.each do |uri|
        lambda{OID2.new(realm, {param=>uri})}.
          should.not.raise
      end
    end
  end

  specify 'return_to should be absolute and be under the realm' do
    lambda{OID2.new(realm, {:return_to => 'http://path'})}.
      should.raise ArgumentError
    lambda{OID2.new(realm, {:return_to => 'http://path/'})}.
      should.raise ArgumentError
    lambda{OID2.new(realm, {:return_to => 'http://path/arf'})}.
      should.not.raise
    lambda{OID2.new(realm, {:return_to => 'http://path/arf/'})}.
      should.not.raise
    lambda{OID2.new(realm, {:return_to => 'http://path/arf/blargh'})}.
      should.not.raise
  end
end
