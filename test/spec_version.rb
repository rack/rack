# frozen_string_literal: true

require_relative 'helper'

separate_testing do
  require_relative '../lib/rack/version'
end

describe Rack do
  describe 'version' do
    it 'is a version string' do
      Rack::VERSION.must_match(/\d+\.\d+\.\d+/)
    end
  end
end
