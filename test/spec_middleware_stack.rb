require 'minitest/autorun'
require 'rack/middleware_stack'

describe Rack::MiddlewareStack do
  before do
    @stack = Rack::MiddlewareStack.new
  end

  it "implements #use" do
    assert_respond_to @stack, :use
  end

  it "implements <<" do
    assert_respond_to @stack, :<<
  end

  it "implements #to_app" do
    assert_respond_to @stack, :to_app

  end
end
