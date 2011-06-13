describe Rack::BodyProxy do
  should 'not close more than one time' do
    count = 0
    proxy = Rack::BodyProxy.new([]) { count += 1 }
    proxy.close
    proxy.close
    count.should == 1
  end
end
