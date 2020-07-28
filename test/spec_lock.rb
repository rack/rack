# frozen_string_literal: true

require_relative 'helper'

describe Rack::Lock do
  it "constructs lock when builder is multithreaded" do
    builder = Rack::Builder.new(nil, multithread: true) do
      use Rack::Lock
    end

    app = builder.to_app
    app.must_be_kind_of Rack::Lock::Wrapper
  end

  it "ignores lock when builder is not multithreaded" do
    builder = Rack::Builder.new(nil, multithread: false) do
      use Rack::Lock
    end

    app = builder.to_app
    app.must_be_nil
  end
end
