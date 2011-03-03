require 'rack/middleware'

describe Rack::Middleware do
  should "call app with env" do
    mw = Rack::Middleware.new(lambda { |env| env })
    env = "lol"
    mw.call(env).should.equal env
  end

  should "use the accessor in call so subclasses work" do
    mw = Class.new(Rack::Middleware) {
      def call(env)
        "hi mom!"
      end
    }.new(lambda { |env| env })

    mw.call("lol").should.equal "hi mom!"
  end
end
