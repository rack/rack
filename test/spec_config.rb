# frozen_string_literal: true

require_relative 'helper'

describe Rack::Config do
  it "accept a block that modifies the environment" do
    app = Rack::Builder.new do
      use Rack::Lint
      use Rack::Config do |env|
        env['greeting'] = 'hello'
      end
      run lambda { |env|
        [200, { 'Content-Type' => 'text/plain' }, [env['greeting'] || '']]
      }
    end

    response = Rack::MockRequest.new(app).get('/')
    response.body.must_equal 'hello'
  end
end
