# frozen_string_literal: true

require_relative 'helper'

separate_testing do
  require_relative '../lib/rack/config'
  require_relative '../lib/rack/lint'
  require_relative '../lib/rack/builder'
  require_relative '../lib/rack/mock_request'
end

describe Rack::Config do
  it "accept a block that modifies the environment" do
    app = Rack::Builder.new do
      use Rack::Lint
      use Rack::Config do |env|
        env['greeting'] = 'hello'
      end
      run lambda { |env|
        [200, { 'content-type' => 'text/plain' }, [env['greeting'] || '']]
      }
    end

    response = Rack::MockRequest.new(app).get('/')
    response.body.must_equal 'hello'
  end
end
