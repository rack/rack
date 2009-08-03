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
    def initialize(map = {})
      remap(map)
    end

    def remap(map)
      @mapping = map.map { |location, app|
        if location =~ %r{\Ahttps?://(.*?)(/.*)}
          host, location = $1, $2
        else
          host = nil
        end

        unless location[0] == ?/
          raise ArgumentError, "paths need to start with /"
        end
        location = location.chomp('/')

        [host, location, app]
      }.sort_by { |(h, l, a)| [h ? -h.size : (-1.0 / 0.0), -l.size] }  # Longest path first
    end

    def call(env)
      path = env[Const::ENV_PATH_INFO].to_s.squeeze("/")
      script_name = env[Const::ENV_SCRIPT_NAME]
      hHost, sName, sPort = env.values_at(Const::ENV_HTTP_HOST, Const::ENV_SERVER_NAME, Const::ENV_SERVER_PORT)
      @mapping.each { |host, location, app|
        next unless (hHost == host || sName == host \
          || (host.nil? && (hHost == sName || hHost == sName+':'+sPort)))
        next unless location == path[0, location.size]
        next unless path[location.size] == nil || path[location.size] == ?/

        return app.call(
          env.merge(
            Const::ENV_SCRIPT_NAME => (script_name + location),
            Const::ENV_PATH_INFO   => path[location.size..-1]))
      }
      [404, {Const::CONTENT_TYPE => "text/plain"}, ["Not Found: #{path}"]]
    end
  end
end
