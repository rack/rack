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
  # Set custom HTTP Headers for based on rules:
  #
  #     use Rack::Static, :root => 'public',
  #         :header_rules => [
  #           [rule, {header_field => content, header_field => content}],
  #           [rule, {header_field => content}]
  #         ]
  #
  #  Rules for selecting files:
  #
  #  1) All files
  #     Provide the :all symbol
  #     :all => Matches every file
  #
  #  2) Folders
  #     Provide the folder path as a string
  #     '/folder' or '/folder/subfolder' => Matches files in a certain folder
  #
  #  3) File Extensions
  #     Provide the file extensions as an array
  #     ['css', 'js'] or %w(css js) => Matches files ending in .css or .js
  #
  #  4) Regular Expressions / Regexp
  #     Provide a regular expression
  #     %r{\.(?:css|js)\z} => Matches files ending in .css or .js
  #     /\.(?:eot|ttf|otf|woff|svg)\z/ => Matches files ending in
  #       the most common web font formats (.eot, .ttf, .otf, .woff, .svg)
  #       Note: This Regexp is available as a shortcut, using the :fonts rule
  #
  #  5) Font Shortcut
  #     Provide the :fonts symbol
  #     :fonts => Uses the Regexp rule stated right above to match all common web font endings
  #
  #  Rule Ordering:
  #    Rules are applied in the order that they are provided.
  #    List rather general rules above special ones.
  #
  #  Complete example use case including HTTP header rules:
  #
  #     use Rack::Static, :root => 'public',
  #         :header_rules => [
  #           # Cache all static files in public caches (e.g. Rack::Cache)
  #           #  as well as in the browser
  #           [:all, {'Cache-Control' => 'public, max-age=31536000'}],
  #
  #           # Provide web fonts with cross-origin access-control-headers
  #           #  Firefox requires this when serving assets using a Content Delivery Network
  #           [:fonts, {'Access-Control-Allow-Origin' => '*'}]
  #         ]
  #
  class Static

    def initialize(app, options={})
      @app = app
      @urls = options[:urls] || ["/favicon.ico"]
      @index = options[:index]
      @root = options[:root] || Dir.pwd

      # HTTP Headers
      @header_rules = options[:header_rules] || []
      # Allow for legacy :cache_control option while prioritizing global header_rules setting
      @header_rules.insert(0, [:all, {'Cache-Control' => options[:cache_control]}]) if options[:cache_control]
      @headers = {}

      @file_server = Rack::File.new(@root, @headers)
    end

    # Look up `path` in urls.
    # If urls is an Array, return `path` if there is a match, otherwise nil.
    # If urls is a Hash, return path "overwrite" if there is a match.
    # Otherwise return nil.
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
      path = env["PATH_INFO"].strip
      route = route_file(path)

      if route
        if @index && directory?(route)
          route = route.chomp('/') + '/' + @index
        end
        @path = env["PATH_INFO"] = route
        apply_header_rules
        @file_server.call(env)
      elsif @index && directory?(path)
        @path = env["PATH_INFO"] = path.chomp('/') + '/' + @index
        apply_header_rules
        @file_server.call(env)
      else
        @path = path
        @app.call(env)
      end
    end

    # Convert HTTP header rules to HTTP headers.
    def apply_header_rules
      @header_rules.each do |rule, headers|
        apply_rule(rule, headers)
      end
    end

    def apply_rule(rule, headers)
      case rule
      when :all    # All files
        set_headers(headers)
      when :fonts  # Fonts Shortcut
        set_headers(headers) if @path.match(/\.(?:ttf|otf|eot|woff|svg)\z/)
      when String  # Folder
        path = ::Rack::Utils.unescape(@path)
        set_headers(headers) if (path.start_with?(rule) || path.start_with?('/' + rule))
      when Array   # Extension/Extensions
        extensions = rule.join('|')
        set_headers(headers) if @path.match(/\.(#{extensions})\z/)
      when Regexp  # Flexible Regexp
        set_headers(headers) if @path.match(rule)
      else
      end
    end

    def set_headers(headers)
      headers.each { |field, content| @headers[field] = content }
    end

    # Determine if a path is a directory by looking for
    # trailing `/` or, failing that, checking the file system.
    def directory?(path)
      path.end_with?('/') || ::File.directory?(::File.join(@root, path.to_s))
    end

  end
end
