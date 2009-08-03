require 'rack/utils'

module Rack
  # Rack::Request provides a convenient interface to a Rack
  # environment.  It is stateless, the environment +env+ passed to the
  # constructor will be directly modified.
  #
  #   req = Rack::Request.new(env)
  #   req.post?
  #   req.params["data"]
  #
  # The environment hash passed will store a reference to the Request object
  # instantiated so that it will only instantiate if an instance of the Request
  # object doesn't already exist.

  class Request
    # The environment of the request.
    attr_reader :env

    def initialize(env)
      @env = env
    end

    def body;            @env[Const::RACK_INPUT]                  end
    def scheme;          @env[Const::RACK_URL_SCHEME]             end
    def script_name;     @env[Const::ENV_SCRIPT_NAME].to_s            end
    def path_info;       @env[Const::ENV_PATH_INFO].to_s              end
    def port;            @env[Const::ENV_SERVER_PORT].to_i            end
    def request_method;  @env[Const::ENV_REQUEST_METHOD]              end
    def query_string;    @env[Const::ENV_QUERY_STRING].to_s           end
    def content_length;  @env[Const::ENV_CONTENT_LENGTH]              end
    def content_type;    @env[Const::ENV_CONTENT_TYPE]                end
    def session;         @env[Const::RACK_SESSION] ||= {}         end
    def session_options; @env[Const::RACK_SESSION_OPTIONS] ||= {} end

    # The media type (type/subtype) portion of the CONTENT_TYPE header
    # without any media type parameters. e.g., when CONTENT_TYPE is
    # "text/plain;charset=utf-8", the media-type is "text/plain".
    #
    # For more information on the use of media types in HTTP, see:
    # http://www.w3.org/Protocols/rfc2616/rfc2616-sec3.html#sec3.7
    def media_type
      content_type && content_type.split(/\s*[;,]\s*/, 2).first.downcase
    end

    # The media type parameters provided in CONTENT_TYPE as a Hash, or
    # an empty Hash if no CONTENT_TYPE or media-type parameters were
    # provided.  e.g., when the CONTENT_TYPE is "text/plain;charset=utf-8",
    # this method responds with the following Hash:
    #   { 'charset' => 'utf-8' }
    def media_type_params
      return {} if content_type.nil?
      content_type.split(/\s*[;,]\s*/)[1..-1].
        collect { |s| s.split('=', 2) }.
        inject({}) { |hash,(k,v)| hash[k.downcase] = v ; hash }
    end

    # The character set of the request body if a "charset" media type
    # parameter was given, or nil if no "charset" was specified. Note
    # that, per RFC2616, text/* media types that specify no explicit
    # charset are to be considered ISO-8859-1.
    def content_charset
      media_type_params['charset']
    end

    def host
      # Remove port number.
      (@env[Const::ENV_HTTP_HOST] || @env[Const::ENV_SERVER_NAME]).to_s.gsub(/:\d+\z/, '')
    end

    def script_name=(s); @env[Const::ENV_SCRIPT_NAME] = s.to_s  end
    def path_info=(s);   @env[Const::ENV_PATH_INFO] = s.to_s    end

    def get?;            request_method == Const::GET           end
    def post?;           request_method == Const::POST          end
    def put?;            request_method == Const::PUT           end
    def delete?;         request_method == Const::DELETE        end
    def head?;           request_method == Const::HEAD          end

    # The set of form-data media-types. Requests that do not indicate
    # one of the media types presents in this list will not be eligible
    # for form-data / param parsing.
    FORM_DATA_MEDIA_TYPES = [
      nil,
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

    # Determine whether the request body contains form-data by checking
    # the request media_type against registered form-data media-types:
    # "application/x-www-form-urlencoded" and "multipart/form-data". The
    # list of form-data media types can be modified through the
    # +FORM_DATA_MEDIA_TYPES+ array.
    def form_data?
      FORM_DATA_MEDIA_TYPES.include?(media_type)
    end

    # Determine whether the request body contains data by checking
    # the request media_type against registered parse-data media-types
    def parseable_data?
      PARSEABLE_DATA_MEDIA_TYPES.include?(media_type)
    end

    QUERY_STRING = 'rack.request.query_string'.freeze
    QUERY_HASH   = 'rack.request.query_hash'.freeze

    # Returns the data recieved in the query string.
    def GET
      if @env[QUERY_STRING] == query_string
        @env[QUERY_HASH]
      else
        @env[QUERY_STRING] = query_string
        @env[QUERY_HASH]   = Utils.parse_nested_query(query_string)
      end
    end

    FORM_INPUT = 'rack.request.form_input'.freeze
    FORM_HASH  = 'rack.request.form_hash'.freeze
    FORM_VARS  = 'rack.request.form_vars'.freeze

    # Returns the data recieved in the request body.
    #
    # This method support both application/x-www-form-urlencoded and
    # multipart/form-data.
    def POST
      if @env[Const::RACK_INPUT].nil?
        raise "Missing rack.input"
      elsif @env[FORM_INPUT].eql? @env[Const::RACK_INPUT]
        @env[FORM_HASH]
      elsif form_data? || parseable_data?
        @env[FORM_INPUT] = @env[Const::RACK_INPUT]
        unless @env[FORM_HASH] = Utils::Multipart.parse_multipart(env)
          form_vars = @env[Const::RACK_INPUT].read

          # Fix for Safari Ajax postings that always append \0
          form_vars.sub!(/\0\z/, '')

          @env[FORM_VARS] = form_vars
          @env[FORM_HASH] = Utils.parse_nested_query(form_vars)

          @env[Const::RACK_INPUT].rewind
        end
        @env[FORM_HASH]
      else
        {}
      end
    end

    # The union of GET and POST data.
    def params
      self.put? ? self.GET : self.GET.update(self.POST)
    rescue EOFError => e
      self.GET
    end

    # shortcut for request.params[key]
    def [](key)
      params[key.to_s]
    end

    # shortcut for request.params[key] = value
    def []=(key, value)
      params[key.to_s] = value
    end

    # like Hash#values_at
    def values_at(*keys)
      keys.map{|key| params[key] }
    end

    # the referer of the client or '/'
    def referer
      @env[Const::ENV_HTTP_REFERER] || '/'
    end
    alias referrer referer


    COOKIE_STRING = 'rack.request.cookie_string'.freeze
    COOKIE_HASH   = 'rack.request.cookie_hash'.freeze

    def cookies
      return {}  unless @env[Const::ENV_HTTP_COOKIE]

      if @env[COOKIE_STRING] == @env[Const::ENV_HTTP_COOKIE]
        @env[COOKIE_HASH]
      else
        @env[COOKIE_STRING] = @env[Const::ENV_HTTP_COOKIE]
        # According to RFC 2109:
        #   If multiple cookies satisfy the criteria above, they are ordered in
        #   the Cookie header such that those with more specific Path attributes
        #   precede those with less specific.  Ordering with respect to other
        #   attributes (e.g., Domain) is unspecified.
        @env[COOKIE_HASH] =
          Utils.parse_query(@env[COOKIE_STRING], ';,').inject({}) {|h,(k,v)|
            h[k] = Array === v ? v.first : v
            h
          }
      end
    end

    def xhr?
      @env[Const::ENV_HTTP_X_REQUESTED_WITH] == "XMLHttpRequest"
    end

    # Tries to return a remake of the original request URL as a string.
    def url
      url = scheme + "://"
      url << host

      if scheme == "https" && port != 443 ||
          scheme == "http" && port != 80
        url << ":#{port}"
      end

      url << fullpath

      url
    end
    
    def path
      script_name + path_info
    end
    
    def fullpath
      query_string.empty? ? path : "#{path}?#{query_string}"
    end

    def accept_encoding
      @env[Const::ENV_HTTP_ACCEPT_ENCODING].to_s.split(/,\s*/).map do |part|
        m = /^([^\s,]+?)(?:;\s*q=(\d+(?:\.\d+)?))?$/.match(part) # From WEBrick

        if m
          [m[1], (m[2] || 1.0).to_f]
        else
          raise "Invalid value for Accept-Encoding: #{part.inspect}"
        end
      end
    end

    def ip
      if addr = @env[Const::ENV_HTTP_X_FORWARDED_FOR]
        addr.split(',').last.strip
      else
        @env[Const::ENV_REMOTE_ADDR]
      end
    end
  end
end
