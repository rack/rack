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
    NEGATIVE_INFINITY = -1.0 / 0.0

    def initialize(map = {})
      remap(map)
    end

    def remap(map)
      @mapping = map.map { |location, app|
        keys = []
        if location =~ %r{\Ahttps?://(.*?)(/.*)}
          host, location = $1, $2
        else
          host = nil
        end

        unless location[0] == ?/
          raise ArgumentError, "paths need to start with /"
        end

        location = location.chomp('/')

        pattern = "^#{Regexp.quote(location).gsub('/', '/+')}(.*)"
        pattern = pattern.gsub(/((:\w+))/) do |match|
          keys << $2[1..-1]
          "([^/?#]+)"
        end
        pattern = Regexp.new(pattern, nil, 'n')

        [host, location, pattern, app, keys]
      }.sort_by do |(host, location, _, _, _)|
        [host ? -host.size : NEGATIVE_INFINITY, -location.gsub(/:\w+\/?/, "").size]
      end
    end

    def call(env)
      path = env["PATH_INFO"]
      script_name = env['SCRIPT_NAME']
      hHost = env['HTTP_HOST']
      sName = env['SERVER_NAME']
      sPort = env['SERVER_PORT']

      @mapping.each do |host, location, pattern, app, keys|
        unless hHost == host \
            || sName == host \
            || (!host && (hHost == sName || hHost == sName+':'+sPort))
          next
        end

        next unless m = pattern.match(path.to_s)

        rest = m.values_at(-1).first
        next unless !rest || rest.empty? || rest[0] == ?/

        env['SCRIPT_NAME'] = (script_name + location)
        env['PATH_INFO'] = rest
        env['rack.url_params'] = Hash[*keys.collect!{|x| x.to_sym}.zip(m.values_at(1..-2)).flatten]

        return app.call(env)
      end

      [404, {"Content-Type" => "text/plain", "X-Cascade" => "pass"}, ["Not Found: #{path}"]]

    ensure
      env['PATH_INFO'] = path
      env['SCRIPT_NAME'] = script_name
    end
  end
end

