describe Rack::BodyProxy do
  should 'not close more than one time' do
    proxy = Rack::BodyProxy.new([]) { }
    proxy.close
    lambda {
      proxy.close
    }.should.raise(IOError)
  end
end
