module Rack

  # The Rack::Static middleware intercepts requests for static files
  # (javascript files, images, stylesheets, etc) based on the url prefixes or
  # route mappings passed in the options, and serves them using a Rack::File
  # object. This allows a Rack stack to serve both static and dynamic content.
  #
  # Examples:
  #
  # Serve all requests beginning with /media from the "media" folder located
  # in the current directory (ie media/*):
  #
  #     use Rack::Static, :urls => ["/media"]
  #
  # Serve all requests beginning with /css or /images from the folder "public"
  # in the current directory (ie public/css/* and public/images/*):
  #
  #     use Rack::Static, :urls => ["/css", "/images"], :root => "public"
  #
  # Serve all requests to / with "index.html" from the folder "public" in the
  # current directory (ie public/index.html):
  #
  #     use Rack::Static, :urls => {"/" => 'index.html'}, :root => 'public'
  #
  # Serve all requests normally from the folder "public" in the current
  # directory but uses index.html as default route for "/"
  #
  #     use Rack::Static, :urls => [""], :root => 'public', :index =>
  #     'index.html'
  #
  # Set a fixed Cache-Control header for all served files:
  #
  #     use Rack::Static, :root => 'public', :cache_control => 'public'
  #

  class Static

    def initialize(app, options={})
      @app = app
      @urls  = options[:urls] || ["/favicon.ico"]
      @index = options[:index]
      @root  = options[:root] || Dir.pwd
      cache_control = options[:cache_control]
      @file_server = Rack::File.new(@root, cache_control)
    end

    # Determine if a path is a directory by looking for
    # trailing `/`, and failing that checking the file system.
    def directory?(path)
      path.end_with?('/') || ::File.directory?(::File.join(@root, path))
    end

    # Look up path in urls, return nil if not present.
    def route_file(path)
      case @urls
      when Array
        @urls.any?{ |url| path.index(url) == 0 } ? path : nil
      when Hash
        @urls[path]
      else
        nil
      end
    end

    def call(env)
      path  = env["PATH_INFO"].strip
      route = route_file(path)

      if route
        if @index && directory?(route)
          route = route.chomp('/') + '/' + @index
        end
        env["PATH_INFO"] = route
        @file_server.call(env)
      elsif @index && directory?(path)
        env["PATH_INFO"] = path.chomp('/') + '/' + @index
        @file_server.call(env)
      else
        @app.call(env)
      end
    end

  end
end
