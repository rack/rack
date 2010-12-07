require 'logger'

module Rack
  # Sets up rack.logger to write to rack.errors stream
  class Logger
    def initialize(app, level = ::Logger::INFO)
      @app, @level = app, level
    end

    def call(env)
      logger = ::Logger.new(env[RACK_VARIABLE::ERRORS])
      logger.level = @level

      env[RACK_VARIABLE::LOGGER] = logger
      @app.call(env)
    end
  end
end
