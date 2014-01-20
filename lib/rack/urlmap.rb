module Rack
  # Rack::URLMap takes a hash mapping urls or paths to apps, and
  # dispatches accordingly.  Support for HTTP/1.1 host names exists if
  # the URLs start with <tt>http://</tt> or <tt>https://</tt>.
  #
  # URLMap modifies the SCRIPT_NAME and PATH_INFO such that the part
  # relevant for dispatch is in the SCRIPT_NAME, and the rest in the
  # PATH_INFO.  This should be taken care of when you need to
  # reconstruct the URL in order to create links.
  #
  # URLMap dispatches in such a way that the longest paths are tried
  # first, since they are most specific.

  class URLMap
    attr_reader :mapping

    def initialize(plain_mapping = {})
      remap(plain_mapping)
    end

    def remap(plain_mapping)
      @mapping = plain_mapping.map { |location, app|
        [StringMatcher.new(location), app]
      }.sort_by do |(matcher, _)|
        matcher.priorities
      end
    end

    def call(env)
      path = env["PATH_INFO"]
      script_name = env['SCRIPT_NAME']
      http_host = env['HTTP_HOST']
      server_name = env['SERVER_NAME']
      server_port = env['SERVER_PORT']

      @mapping.each do |matcher, app|
        next unless matcher.matches? server_name, server_port, http_host, path

        env['SCRIPT_NAME'] = (script_name + matcher.location)
        env['PATH_INFO'] = matcher.rest(path)

        return app.call(env)
      end

      [404, {"Content-Type" => "text/plain", "X-Cascade" => "pass"}, ["Not Found: #{path}"]]

    ensure
      env['PATH_INFO'] = path
      env['SCRIPT_NAME'] = script_name
    end
  end
end

