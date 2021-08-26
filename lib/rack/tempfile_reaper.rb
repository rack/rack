# frozen_string_literal: true

module Rack

  # Middleware tracks and cleans Tempfiles created throughout a request (i.e. Rack::Multipart)
  # Ideas/strategy based on posts by Eric Wong and Charles Oliver Nutter
  # https://groups.google.com/forum/#!searchin/rack-devel/temp/rack-devel/brK8eh-MByw/sw61oJJCGRMJ
  class TempfileReaper
    def initialize(app)
      @app = app
    end

    def call(env)
      env[RACK_TEMPFILES] ||= []

      begin
        status, headers, body = @app.call(env)
      rescue Exception
        env[RACK_TEMPFILES].each(&:close!) unless env[RACK_TEMPFILES].nil?
        raise
      end

      body_proxy = BodyProxy.new(body) do
        env[RACK_TEMPFILES].each(&:close!) unless env[RACK_TEMPFILES].nil?
      end
      [status, headers, body_proxy]
    end
  end
end
