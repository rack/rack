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
  #         :header_rules => {
  #           rule         => { header_field => content },
  #           another_rule => { header_field => content }
  #         }
  #
  #  These rules for generating HTTP Headers are shipped along:
  #  1) Global
  #  :global => Matches every file
  #
  #  Ex.:
  #    :header_rules => {
  #      :global => {'Cache-Control' => 'public, max-age=123'}
  #    }
  #
  #  2) Folders
  #  '/folder' => Matches all files in a certain folder
  #  '/folder/subfolder' => ...
  #    Note: Provide the folder as a string,
  #          with or without the starting slash
  #
  #  3) File Extensions
  #  ['css', 'js'] => Will match all files ending in .css or .js
  #  %w(css js) => ...
  #    Note: Provide the file extensions in an array,
  #          use any ruby syntax you like to set that array up
  #
  #  4) Regular Expressions / Regexp
  #  %r{\.(?:css|js)\z} => will match all files ending in .css or .js
  #  /\.(?:eot|ttf|otf|woff|svg)\z/ => will match all files ending
  #     in the most common web font formats
  #
  #  5) Shortcuts
  #  There is currently only one shortcut defined.
  #  :fonts => will match all files ending in eot, ttf, otf, woff, svg
  #     using the Regexp stated right above
  #
  #  Example use:
  #
  #     use Rack::Static, :root => 'public',
  #         :header_rules => {
  #           # Cache all static files in http caches as well as on the client
  #           :global => { 'Cache-Control' => 'public, max-age=31536000' },
  #           # Provide Web Fonts with Access-Control-Headers
  #           :fonts  => { 'Access-Control-Allow-Origin' => '*' }
  #         }
  #
  #  Note: The rules will be applied in the order they are provided,
  #        thus more special rules further down below can override
  #        general global HTTP header settings
  #
  #  Note: In MRI Ruby 1.8.7, Ruby Enterprise Edition (REE)
  #        or certain versions of Rubinius hashes are unordered.
  #        This means that when you provide rules using a hash
  #        they will be applied in a random, different order
  #        to every file served and each time a file is served.
  #
  #        You can circumvent this issue by providing an array of arrays,
  #        thus encapsulating each rule, as shown here:
  #
  #        use Rack::Static, :root => 'public',
  #          :header_rules => [
  #            [:global => { 'Cache-Control' => 'public, max-age=31536000' }],
  #            [:fonts  => { 'Access-Control-Allow-Origin' => '*' }]
  #           ]
  #

  class Static

    def initialize(app, options={})
      @app = app
      @urls = options[:urls] || ["/favicon.ico"]
      @index = options[:index]
      root = options[:root] || Dir.pwd
      @headers = {}
      @header_rules = options[:header_rules] || {}
      # Allow for legacy :cache_control option while prioritizing global header_rules setting
      if options[:cache_control]
        if @header_rules.instance_of? Array
            cache_control = [{ :global => {'Cache-Control' => options[:cache_control]} }]
            @header_rules.insert(0, cache_control)
        else
          @header_rules[:global] ||= {}
          @header_rules[:global]['Cache-Control'] ||= options[:cache_control]
        end
      end
      @file_server = Rack::File.new(root, @headers)
    end

    def overwrite_file_path(path)
      @urls.kind_of?(Hash) && @urls.key?(path) || @index && path =~ /\/$/
    end

    def route_file(path)
      @urls.kind_of?(Array) && @urls.any? { |url| path.index(url) == 0 }
    end

    def can_serve(path)
      route_file(path) || overwrite_file_path(path)
    end

    def call(env)
      path = env["PATH_INFO"]

      if can_serve(path)
        env["PATH_INFO"] = (path =~ /\/$/ ? path + @index : @urls[path]) if overwrite_file_path(path)
        @path = env["PATH_INFO"]
        set_headers
        @file_server.call(env)
      else
        @app.call(env)
      end
    end

    # Convert header rules to headers
    def set_headers
      if @header_rules.instance_of? Array
        @header_rules.each do |header_rule|
          header_rule[0].each { |rule, headers| apply_rule(rule, headers) } if header_rule
        end
      elsif @header_rules.instance_of? Hash
        @header_rules.each do |rule, headers|
          apply_rule(rule, headers)
        end
      end
    end

    def apply_rule(rule, headers)
      case rule
      when :global # Global
        set_header(headers)
      when :fonts  # Fonts Shortcut
        set_header(headers) if @path.match(%r{\.(?:ttf|otf|eot|woff|svg)\z})
      when String  # Folder
        path = ::Rack::Utils.unescape(@path)
        set_header(headers) if (path.start_with?(rule) || path.start_with?('/' + rule))
      when Array   # Extension/Extensions
        extensions = rule.join('|')
        set_header(headers) if @path.match(%r{\.(#{extensions})\z})
      when Regexp  # Flexible Regexp
        set_header(headers) if @path.match(rule)
      else
      end
    end

    def set_header(headers)
      headers.each { |field, content| @headers[field] = content }
    end

  end
end
