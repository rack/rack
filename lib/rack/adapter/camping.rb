module Rack
  module Adapter
    class Camping
      def initialize(app)
        @app = app
      end

      def call(env)
        env["PATH_INFO"] ||= ""
        env["SCRIPT_NAME"] ||= ""
        controller = @app.run(env['rack.input'], env)
        [controller.status, controller.headers, controller.body]
      end
    end
  end
end
