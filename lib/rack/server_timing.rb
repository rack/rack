# frozen_string_literal: true

require_relative 'utils'

module Rack
  # Sets or appends to a "server-timing" response header, indicating the
  # response time of the request, in milliseconds. The header follows the
  # Server-Timing specification (https://www.w3.org/TR/server-timing/).
  #
  # You can put it right before the application to see the processing
  # time, or before all the other middlewares to include time for them,
  # too.
  class ServerTiming
    DURATION_FORMAT_STRING = "%0.3f" # :nodoc:
    HEADER_NAME = "server-timing" # :nodoc:
    METRIC_NAME = "rack-runtime" # :nodoc:

    def initialize(app, metric_name = METRIC_NAME)
      @app = app
      @metric_name = metric_name
    end

    def call(env)
      start_time = Utils.clock_time
      _, headers, _ = response = @app.call(env)

      duration_ms = (Utils.clock_time - start_time) * 1000

      set_server_timing_header(headers, duration_ms)

      response
    end

    private

    def set_server_timing_header(headers, duration_ms)
      metric = "#{@metric_name};dur=#{DURATION_FORMAT_STRING % duration_ms}"

      headers[HEADER_NAME] = [headers[HEADER_NAME], metric].compact.join(", ")
    end
  end
end
