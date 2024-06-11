# frozen_string_literal: true

require 'logger'
require_relative 'constants'

warn "Rack::Logger is deprecated and will be removed in Rack 3.2.", uplevel: 1

module Rack
  # Sets up rack.logger to write to rack.errors stream
  class Logger
    def initialize(app, level = ::Logger::INFO)
      @app, @level = app, level
    end

    def call(env)
      logger = ::Logger.new(env[RACK_ERRORS])
      logger.level = @level

      env[RACK_LOGGER] = logger
      @app.call(env)
    end
  end
end
