module Rack
  # Rack::CommonLogger forwards every request to an +app+ given, and
  # logs a line in the Apache common log format to the +logger+, or
  # rack.errors by default.
  class CommonLogger
    # Common Log Format: http://httpd.apache.org/docs/1.3/logs.html#common
    # lilith.local - - [07/Aug/2006 23:58:02] "GET / HTTP/1.1" 500 -
    #             %{%s - %s [%s] "%s %s%s %s" %d %s\n} %
    FORMAT = %{%s - %s [%s] "%s %s%s %s" %d %s %0.4f\n}
    TIME_FORMAT = "%d/%b/%Y %H:%M:%S".freeze

    def initialize(app, logger=nil)
      @app = app
      @logger = logger
    end

    def call(env)
      began_at = Time.now
      status, header, body = @app.call(env)
      header = Utils::HeaderHash.new(header)
      log(env, status, header, began_at)
      [status, header, body]
    end

    private

    def log(env, status, header, began_at)
      now = Time.now
      length = extract_content_length(header)

      logger = @logger || env[RACK_VARIABLE::ERRORS]
      logger.write FORMAT % [
        env[CGI_VARIABLE::HTTP_X_FORWARDED_FOR] || env[CGI_VARIABLE::REMOTE_ADDR] || "-",
        env[CGI_VARIABLE::REMOTE_USER] || "-",
        now.strftime(TIME_FORMAT),
        env[CGI_VARIABLE::REQUEST_METHOD],
        env[CGI_VARIABLE::PATH_INFO],
        env[CGI_VARIABLE::QUERY_STRING].empty? ? "" : "?"+env[CGI_VARIABLE::QUERY_STRING],
        env[CGI_VARIABLE::HTTP_VERSION],
        status.to_s[0..3],
        length,
        now - began_at ]
    end

    def extract_content_length(headers)
      value = headers[HTTP_HEADER::CONTENT_LENGTH] or return '-'
      value.to_s == '0' ? '-' : value
    end
  end
end
