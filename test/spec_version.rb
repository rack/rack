# frozen_string_literal: true

require_relative 'helper'

separate_testing do
  require_relative '../lib/rack/version'
end

describe Rack do
  describe 'version' do
    it 'defaults to a hard-coded api version' do
      Rack.version.must_match(/\d+\.\d+\.\d+/)
    end
  end
end
