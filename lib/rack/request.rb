require 'rack/utils'
require 'rack/media_type'

module Rack
  # Rack::Request provides a convenient interface to a Rack
  # environment.  It is stateless, the environment +env+ passed to the
  # constructor will be directly modified.
  #
  #   req = Rack::Request.new(env)
  #   req.post?
  #   req.params["data"]

  class Request
    HTTP_X_FORWARDED_SCHEME = 'HTTP_X_FORWARDED_SCHEME'.freeze
    HTTP_X_FORWARDED_PROTO  = 'HTTP_X_FORWARDED_PROTO'.freeze
    HTTP_X_FORWARDED_HOST   = 'HTTP_X_FORWARDED_HOST'.freeze
    HTTP_X_FORWARDED_PORT   = 'HTTP_X_FORWARDED_PORT'.freeze
    HTTP_X_FORWARDED_SSL    = 'HTTP_X_FORWARDED_SSL'.freeze

    # The environment of the request.
    attr_reader :env

    def initialize(env)
      @env = env
    end

    def body;            @env[RACK_INPUT]                       end
    def script_name;     @env[SCRIPT_NAME].to_s                   end
    def path_info;       @env[PATH_INFO].to_s                     end
    def request_method;  @env[REQUEST_METHOD]                     end
    def query_string;    @env[QUERY_STRING].to_s                  end
    def content_length;  @env['CONTENT_LENGTH']                   end

    def content_type
      content_type = @env['CONTENT_TYPE']
      content_type.nil? || content_type.empty? ? nil : content_type
    end

    def session;         @env[RACK_SESSION] ||= {}              end
    def session_options; @env[RACK_SESSION_OPTIONS] ||= {}      end
    def logger;          @env[RACK_LOGGER]                      end

    # The media type (type/subtype) portion of the CONTENT_TYPE header
    # without any media type parameters. e.g., when CONTENT_TYPE is
    # "text/plain;charset=utf-8", the media-type is "text/plain".
    #
    # For more information on the use of media types in HTTP, see:
    # http://www.w3.org/Protocols/rfc2616/rfc2616-sec3.html#sec3.7
    def media_type
      @media_type ||= MediaType.type(content_type)
    end

    # The media type parameters provided in CONTENT_TYPE as a Hash, or
    # an empty Hash if no CONTENT_TYPE or media-type parameters were
    # provided.  e.g., when the CONTENT_TYPE is "text/plain;charset=utf-8",
    # this method responds with the following Hash:
    #   { 'charset' => 'utf-8' }
    def media_type_params
      @media_type_params ||= MediaType.params(content_type)
    end

    # The character set of the request body if a "charset" media type
    # parameter was given, or nil if no "charset" was specified. Note
    # that, per RFC2616, text/* media types that specify no explicit
    # charset are to be considered ISO-8859-1.
    def content_charset
      media_type_params['charset']
    end

    def scheme
      if @env[HTTPS] == 'on'
        'https'
      elsif @env[HTTP_X_FORWARDED_SSL] == 'on'
        'https'
      elsif @env[HTTP_X_FORWARDED_SCHEME]
        @env[HTTP_X_FORWARDED_SCHEME]
      elsif @env[HTTP_X_FORWARDED_PROTO]
        @env[HTTP_X_FORWARDED_PROTO].split(',')[0]
      else
        @env[RACK_URL_SCHEME]
      end
    end

    # Get a request specific value for `name`. If a block is given, it yields
    # to the block if the value hasn't been set on the request.
    def get_header(name)
      if block_given?
        @env.fetch(name) { |x| yield x }
      else
        @env[name]
      end
    end

    # Delete a request specific value for `name`.
    def delete_header(name)
      @env.delete name
    end

    # Set a request specific value for `name` to `v`
    def set_header(name, v)
      @env[name] = v
    end

    # Predicate method to test to see if `name` has been set as request
    # specific data
    def has_header?(name)
      @env.key? name
    end

    # Loops through each key / value pair in the request specific data.
    def each_header(&block)
      @env.each(&block)
    end

    def ssl?
      scheme == 'https'
    end

    def host_with_port
      if forwarded = @env[HTTP_X_FORWARDED_HOST]
        forwarded.split(/,\s?/).last
      else
        @env[HTTP_HOST] || "#{@env[SERVER_NAME] || @env[SERVER_ADDR]}:#{@env[SERVER_PORT]}"
      end
    end

    def port
      if port = host_with_port.split(/:/)[1]
        port.to_i
      elsif port = @env[HTTP_X_FORWARDED_PORT]
        port.to_i
      elsif @env.has_key?(HTTP_X_FORWARDED_HOST)
        DEFAULT_PORTS[scheme]
      elsif @env.has_key?(HTTP_X_FORWARDED_PROTO)
        DEFAULT_PORTS[@env[HTTP_X_FORWARDED_PROTO].split(',')[0]]
      else
        @env[SERVER_PORT].to_i
      end
    end

    def host
      # Remove port number.
      host_with_port.to_s.sub(/:\d+\z/, '')
    end

    def script_name=(s); @env[SCRIPT_NAME] = s.to_s             end
    def path_info=(s);   @env[PATH_INFO] = s.to_s               end


    # Checks the HTTP request method (or verb) to see if it was of type DELETE
    def delete?;  request_method == DELETE  end

    # Checks the HTTP request method (or verb) to see if it was of type GET
    def get?;     request_method == GET       end

    # Checks the HTTP request method (or verb) to see if it was of type HEAD
    def head?;    request_method == HEAD      end

    # Checks the HTTP request method (or verb) to see if it was of type OPTIONS
    def options?; request_method == OPTIONS end

    # Checks the HTTP request method (or verb) to see if it was of type LINK
    def link?;    request_method == LINK    end

    # Checks the HTTP request method (or verb) to see if it was of type PATCH
    def patch?;   request_method == PATCH   end

    # Checks the HTTP request method (or verb) to see if it was of type POST
    def post?;    request_method == POST    end

    # Checks the HTTP request method (or verb) to see if it was of type PUT
    def put?;     request_method == PUT     end

    # Checks the HTTP request method (or verb) to see if it was of type TRACE
    def trace?;   request_method == TRACE   end

    # Checks the HTTP request method (or verb) to see if it was of type UNLINK
    def unlink?;  request_method == UNLINK  end


    # The set of form-data media-types. Requests that do not indicate
    # one of the media types presents in this list will not be eligible
    # for form-data / param parsing.
    FORM_DATA_MEDIA_TYPES = [
      'application/x-www-form-urlencoded',
      'multipart/form-data'
    ]

    # The set of media-types. Requests that do not indicate
    # one of the media types presents in this list will not be eligible
    # for param parsing like soap attachments or generic multiparts
    PARSEABLE_DATA_MEDIA_TYPES = [
      'multipart/related',
      'multipart/mixed'
    ]

    # Default ports depending on scheme. Used to decide whether or not
    # to include the port in a generated URI.
    DEFAULT_PORTS = { 'http' => 80, 'https' => 443, 'coffee' => 80 }

    # Determine whether the request body contains form-data by checking
    # the request Content-Type for one of the media-types:
    # "application/x-www-form-urlencoded" or "multipart/form-data". The
    # list of form-data media types can be modified through the
    # +FORM_DATA_MEDIA_TYPES+ array.
    #
    # A request body is also assumed to contain form-data when no
    # Content-Type header is provided and the request_method is POST.
    def form_data?
      type = media_type
      meth = env[RACK_METHODOVERRIDE_ORIGINAL_METHOD] || env[REQUEST_METHOD]
      (meth == POST && type.nil?) || FORM_DATA_MEDIA_TYPES.include?(type)
    end

    # Determine whether the request body contains data by checking
    # the request media_type against registered parse-data media-types
    def parseable_data?
      PARSEABLE_DATA_MEDIA_TYPES.include?(media_type)
    end

    # Returns the data received in the query string.
    def GET
      if @env[RACK_REQUEST_QUERY_STRING] == query_string
        @env[RACK_REQUEST_QUERY_HASH]
      else
        query_hash = parse_query(query_string, '&;')
        @env[RACK_REQUEST_QUERY_STRING ] = query_string
        @env[RACK_REQUEST_QUERY_HASH]   = query_hash
      end
    end

    # Returns the data received in the request body.
    #
    # This method support both application/x-www-form-urlencoded and
    # multipart/form-data.
    def POST
      if @env[RACK_INPUT].nil?
        raise "Missing rack.input"
      elsif @env[RACK_REQUEST_FORM_INPUT] == @env[RACK_INPUT]
        @env[RACK_REQUEST_FORM_HASH]
      elsif form_data? || parseable_data?
        unless @env[RACK_REQUEST_FORM_HASH] = parse_multipart(env)
          form_vars = @env[RACK_INPUT].read

          # Fix for Safari Ajax postings that always append \0
          # form_vars.sub!(/\0\z/, '') # performance replacement:
          form_vars.slice!(-1) if form_vars[-1] == ?\0

          @env[RACK_REQUEST_FORM_VARS] = form_vars
          @env[RACK_REQUEST_FORM_HASH] = parse_query(form_vars, '&')

          @env[RACK_INPUT].rewind
        end
        @env[RACK_REQUEST_FORM_INPUT ] = @env[RACK_INPUT]
        @env[RACK_REQUEST_FORM_HASH]
      else
        {}
      end
    end

    # The union of GET and POST data.
    #
    # Note that modifications will not be persisted in the env. Use update_param or delete_param if you want to destructively modify params.
    def params
      @params ||= self.GET.merge(self.POST)
    rescue EOFError
      self.GET.dup
    end

    # Destructively update a parameter, whether it's in GET and/or POST. Returns nil.
    #
    # The parameter is updated wherever it was previous defined, so GET, POST, or both. If it wasn't previously defined, it's inserted into GET.
    #
    # env['rack.input'] is not touched.
    def update_param(k, v)
      found = false
      if self.GET.has_key?(k)
        found = true
        self.GET[k] = v
      end
      if self.POST.has_key?(k)
        found = true
        self.POST[k] = v
      end
      unless found
        self.GET[k] = v
      end
      @params = nil
    end

    # Destructively delete a parameter, whether it's in GET or POST. Returns the value of the deleted parameter.
    #
    # If the parameter is in both GET and POST, the POST value takes precedence since that's how #params works.
    #
    # env['rack.input'] is not touched.
    def delete_param(k)
      v = [ self.POST.delete(k), self.GET.delete(k) ].compact.first
      @params = nil
      v
    end

    # shortcut for request.params[key]
    def [](key)
      params[key.to_s]
    end

    # shortcut for request.params[key] = value
    #
    # Note that modifications will not be persisted in the env. Use update_param or delete_param if you want to destructively modify params.
    def []=(key, value)
      params[key.to_s] = value
    end

    # like Hash#values_at
    def values_at(*keys)
      keys.map{|key| params[key] }
    end

    # the referer of the client
    def referer
      @env['HTTP_REFERER']
    end
    alias referrer referer

    def user_agent
      @env['HTTP_USER_AGENT']
    end

    def cookies
      hash   = @env[RACK_REQUEST_COOKIE_HASH] ||= {}
      string = @env[HTTP_COOKIE]

      return hash if string == @env[RACK_REQUEST_COOKIE_STRING]
      hash.replace Utils.parse_cookies(@env)
      @env[RACK_REQUEST_COOKIE_STRING] = string
      hash
    end

    def query_parser
      Utils.default_query_parser
    end

    def xhr?
      @env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    end

    def base_url
      url = "#{scheme}://#{host}"
      url << ":#{port}" if port != DEFAULT_PORTS[scheme]
      url
    end

    # Tries to return a remake of the original request URL as a string.
    def url
      base_url + fullpath
    end

    def path
      script_name + path_info
    end

    def fullpath
      query_string.empty? ? path : "#{path}?#{query_string}"
    end

    def accept_encoding
      parse_http_accept_header(@env["HTTP_ACCEPT_ENCODING"])
    end

    def accept_language
      parse_http_accept_header(@env["HTTP_ACCEPT_LANGUAGE"])
    end

    def trusted_proxy?(ip)
      ip =~ /\A127\.0\.0\.1\Z|\A(10|172\.(1[6-9]|2[0-9]|30|31)|192\.168)\.|\A::1\Z|\Afd[0-9a-f]{2}:.+|\Alocalhost\Z|\Aunix\Z|\Aunix:/i
    end

    def ip
      remote_addrs = split_ip_addresses(@env['REMOTE_ADDR'])
      remote_addrs = reject_trusted_ip_addresses(remote_addrs)

      return remote_addrs.first if remote_addrs.any?

      forwarded_ips = split_ip_addresses(@env['HTTP_X_FORWARDED_FOR'])

      return reject_trusted_ip_addresses(forwarded_ips).last || @env["REMOTE_ADDR"]
    end

    protected
      def split_ip_addresses(ip_addresses)
        ip_addresses ? ip_addresses.strip.split(/[,\s]+/) : []
      end

      def reject_trusted_ip_addresses(ip_addresses)
        ip_addresses.reject { |ip| trusted_proxy?(ip) }
      end

      def parse_query(qs, d='&')
        query_parser.parse_nested_query(qs, d)
      end

      def parse_multipart(env)
        Rack::Multipart.parse_multipart(env, query_parser)
      end

      def parse_http_accept_header(header)
        header.to_s.split(/\s*,\s*/).map do |part|
          attribute, parameters = part.split(/\s*;\s*/, 2)
          quality = 1.0
          if parameters and /\Aq=([\d.]+)/ =~ parameters
            quality = $1.to_f
          end
          [attribute, quality]
        end
      end
  end
end
