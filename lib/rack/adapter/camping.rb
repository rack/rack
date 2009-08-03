module Rack
  module Adapter
    class Camping
      def initialize(app)
        @app = app
      end

      def call(env)
        env[Const::ENV_PATH_INFO] ||= ""
        env[Const::ENV_SCRIPT_NAME] ||= ""
        controller = @app.run(env[Const::RACK_INPUT], env)
        h = controller.headers
        h.each_pair do |k,v|
          if v.kind_of? URI
            h[k] = v.to_s
          end
        end
        [controller.status, controller.headers, [controller.body.to_s]]
      end
    end
  end
end
