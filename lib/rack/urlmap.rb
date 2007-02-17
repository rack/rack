module Rack
  class URLMap
    def initialize(map)
      @mapping = map.map { |location, app|
        if location =~ %r{\Ahttps?://(.*?)(/.*)}
          host, location = $1, $2
        else
          host = nil
        end
        [host, location, app]
      }
      @mapping.sort_by { |(h, l, a)| -l.size }    # Longest path first
    end

    def call(env)
      path = "#{env["SCRIPT_NAME"]}#{env["PATH_INFO"]}".squeeze("/")

      @mapping.each { |host, location, app|
        if (env["HTTP_HOST"] == host ||
            env["SERVER_NAME"] == host ||
            (host == nil && env["HTTP_HOST"] == env["SERVER_NAME"])) &&
           location == path[0, location.size] && (path[location.size] == nil ||
                                                  path[location.size] == ?/)
          env["SCRIPT_NAME"] = location.dup
          env["PATH_INFO"] = path[location.size..-1]
          env["PATH_INFO"].gsub!(/\/\z/, '')
          env["PATH_INFO"] = "/"  if env["PATH_INFO"].empty?
          return app.call(env)
        end
      }
      [404, {"Content-Type" => "text/plain"}, ["Not Found: #{path}"]]
    end
  end
end

