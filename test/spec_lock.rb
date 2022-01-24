# frozen_string_literal: true

require_relative 'helper'

describe Rack::Lock do
  it "constructs lock when builder is multithreaded" do
    x = Object.new
    builder = Rack::Builder.new(config: Rack::Builder::Config.new(multithread: true)) do
      use Rack::Lock
      run x
    end

    builder.to_app.must_be_kind_of Rack::Lock
  end

  it "ignores lock when builder is not multithreaded" do
    x = Object.new
    builder = Rack::Builder.new(config: Rack::Builder::Config.new(multithread: false)) do
      use Rack::Lock
      run x
    end

    builder.to_app.must_be_same_as x
  end
end
