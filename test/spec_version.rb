require 'minitest/bacon'
# -*- encoding: utf-8 -*-
require 'rack'

describe Rack do
  describe 'version' do
    it 'defaults to a hard-coded api version' do
      Rack.version.should.equal("1.3")
    end
  end
end
