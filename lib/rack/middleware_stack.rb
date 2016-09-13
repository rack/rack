module Rack
  # A Middleware Stack accepts being injected with new middleware (+use+) and
  # can be transformed into an app (+to_app+)
  class MiddlewareStack
   
    def initialize
      @middlewares = []
    end

    def <<(midproc)
      @middlewares << midproc
    end
 
    def use(middleware, *args, &block)
      @middlewares.unshift build_middleware(middleware, *args, &block)
    end

    def to_app(app)
      @middlewares.inject(app) { |a, mid| mid[a] }
    end

    private

    def build_middleware(middleware, *args, &block)
      ->(app) { middleware.new(app, *args, &block) }
    end

  end
end
