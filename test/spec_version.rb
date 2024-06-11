# frozen_string_literal: true

require_relative 'helper'

separate_testing do
  require_relative '../lib/rack/version'
end

describe Rack do
  describe 'VERSION' do
    it 'is a version string' do
      Rack::VERSION.must_match(/\d+\.\d+\.\d+/)
    end
  end

  describe 'RELEASE' do
    it 'is the same as VERSION' do
      Rack::RELEASE.must_equal Rack::VERSION
    end
  end

  describe '.release' do
    it 'returns the version string' do
      Rack.release.must_equal Rack::VERSION
    end
  end
end
