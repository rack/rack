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

    CONTENT_TYPE_SPLITTER = /\s*[;,]\s*/.freeze
    CHARSET = "charset".freeze
    ON = "on".freeze
    HTTP_SCHEME = "http".freeze
    HTTPS_SCHEME = "https".freeze
    SERVER_PORT_PATTERN = /:\d+\z/.freeze
    XML_HTTP_REQUEST = "XMLHttpRequest".freeze
    COMMA_DELIMTED_SPLITTER = /,\s*/.freeze
    ACCEPT_ENCODING_SPLITTER = /^([^\s,]+?)(?:;\s*q=(\d+(?:\.\d+)?))?$/.freeze
    
    def initialize(env)
      @env = env
    end

    def body;            @env[RACK_VARIABLE::INPUT]                       end
    def script_name;     @env[CGI_VARIABLE::SCRIPT_NAME].to_s                 end
    def path_info;       @env[CGI_VARIABLE::PATH_INFO].to_s                   end
    def request_method;  @env[CGI_VARIABLE::REQUEST_METHOD]                   end
    def query_string;    @env[CGI_VARIABLE::QUERY_STRING].to_s                end
    def content_length;  @env[CGI_VARIABLE::CONTENT_LENGTH]                   end
    def content_type;    @env[CGI_VARIABLE::CONTENT_TYPE]                     end
    def session;         @env[RACK_VARIABLE::SESSION] ||= {}              end
    def session_options; @env[RACK_VARIABLE::SESSION_OPTIONS] ||= {}      end
    def logger;          @env[RACK_VARIABLE::LOGGER]                      end

    # The media type (type/subtype) portion of the CONTENT_TYPE header
    # without any media type parameters. e.g., when CONTENT_TYPE is
    # "text/plain;charset=utf-8", the media-type is "text/plain".
    #
    # For more information on the use of media types in HTTP, see:
    # http://www.w3.org/Protocols/rfc2616/rfc2616-sec3.html#sec3.7
    def media_type
      content_type && content_type.split(CONTENT_TYPE_SPLITTER, 2).first.downcase
    end

    # The media type parameters provided in CONTENT_TYPE as a Hash, or
    # an empty Hash if no CONTENT_TYPE or media-type parameters were
    # provided.  e.g., when the CONTENT_TYPE is "text/plain;charset=utf-8",
    # this method responds with the following Hash:
    #   { 'charset' => 'utf-8' }
    def media_type_params
      return {} if content_type.nil?
      Hash[*content_type.split(CONTENT_TYPE_SPLITTER)[1..-1].
        collect { |s| s.split('=', 2) }.
        map { |k,v| [k.downcase, v] }.flatten]
    end

    # The character set of the request body if a "charset" media type
    # parameter was given, or nil if no "charset" was specified. Note
    # that, per RFC2616, text/* media types that specify no explicit
    # charset are to be considered ISO-8859-1.
    def content_charset
      media_type_params[CHARSET]
    end

    def scheme
      if @env[CGI_VARIABLE::HTTPS] == ON
        'https'
      elsif @env[CGI_VARIABLE::HTTP_X_FORWARDED_PROTO]
        @env[CGI_VARIABLE::HTTP_X_FORWARDED_PROTO].split(',')[0]
      else
        @env[RACK_VARIABLE::URL_SCHEME]
      end
    end

    def ssl?
      scheme == HTTPS_SCHEME
    end

    def host_with_port
      if forwarded = @env[CGI_VARIABLE::HTTP_X_FORWARDED_HOST]
        forwarded.split(/,\s?/).last
      else
        @env[CGI_VARIABLE::HTTP_HOST] || "#{@env[CGI_VARIABLE::SERVER_NAME] || @env[CGI_VARIABLE::SERVER_ADDR]}:#{@env[CGI_VARIABLE::SERVER_PORT]}"
      end
    end
    
    def port
      host, port = host_with_port.split(':')
      
      (port || @env[CGI_VARIABLE::SERVER_PORT]).to_i
    end

    def host
      # Remove port number.
      host_with_port.to_s.gsub(SERVER_PORT_PATTERN, '')
    end

    def script_name=(s); @env[CGI_VARIABLE::SCRIPT_NAME] = s.to_s             end
    def path_info=(s);   @env[CGI_VARIABLE::PATH_INFO] = s.to_s               end

    def delete?;  request_method == HTTP_METHOD::DELETE  end
    def get?;     request_method == HTTP_METHOD::GET     end
    def head?;    request_method == HTTP_METHOD::HEAD    end
    def options?; request_method == HTTP_METHOD::OPTIONS end
    def post?;    request_method == HTTP_METHOD::POST    end
    def put?;     request_method == HTTP_METHOD::PUT     end
    def trace?;   request_method == HTTP_METHOD::TRACE   end

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
      meth = env[RACK_VARIABLE::METHODOVERRIDE_ORIGINAL_METHOD] || env[CGI_VARIABLE::REQUEST_METHOD]
      (meth == HTTP_METHOD::POST && type.nil?) || FORM_DATA_MEDIA_TYPES.include?(type)
    end

    # Determine whether the request body contains data by checking
    # the request media_type against registered parse-data media-types
    def parseable_data?
      PARSEABLE_DATA_MEDIA_TYPES.include?(media_type)
    end

    # Returns the data recieved in the query string.
    def GET
      if @env[RACK_VARIABLE::REQUEST_QUERY_STRING] == query_string
        @env[RACK_VARIABLE::REQUEST_QUERY_HASH]
      else
        @env[RACK_VARIABLE::REQUEST_QUERY_STRING] = query_string
        @env[RACK_VARIABLE::REQUEST_QUERY_HASH]   = parse_query(query_string)
      end
    end

    # Returns the data recieved in the request body.
    #
    # This method support both application/x-www-form-urlencoded and
    # multipart/form-data.
    def POST
      if @env[RACK_VARIABLE::INPUT].nil?
        raise "Missing rack.input"
      elsif @env[RACK_VARIABLE::REQUEST_FORM_INPUT].eql? @env[RACK_VARIABLE::INPUT]
        @env[RACK_VARIABLE::REQUEST_FORM_HASH]
      elsif form_data? || parseable_data?
        @env[RACK_VARIABLE::REQUEST_FORM_INPUT] = @env[RACK_VARIABLE::INPUT]
        unless @env[RACK_VARIABLE::REQUEST_FORM_HASH] = parse_multipart(env)
          form_vars = @env[RACK_VARIABLE::INPUT].read

          # Fix for Safari Ajax postings that always append \0
          form_vars.sub!(/\0\z/, '')

          @env[RACK_VARIABLE::REQUEST_FORM_VARS] = form_vars
          @env[RACK_VARIABLE::REQUEST_FORM_HASH] = parse_query(form_vars)

          @env[RACK_VARIABLE::INPUT].rewind
        end
        @env[RACK_VARIABLE::REQUEST_FORM_HASH]
      else
        {}
      end
    end

    # The union of GET and POST data.
    def params
      self.GET.update(self.POST)
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

    # the referer of the client
    def referer
      @env[CGI_VARIABLE::HTTP_REFERER]
    end
    alias referrer referer

    def user_agent
      @env[CGI_VARIABLE::HTTP_USER_AGENT]
    end

    def cookies
      return {}  unless @env[CGI_VARIABLE::HTTP_COOKIE]

      if @env[RACK_VARIABLE::REQUEST_COOKIE_STRING] == @env[CGI_VARIABLE::HTTP_COOKIE]
        @env[RACK_VARIABLE::REQUEST_COOKIE_HASH]
      else
        @env[RACK_VARIABLE::REQUEST_COOKIE_STRING] = @env[CGI_VARIABLE::HTTP_COOKIE]
        # According to RFC 2109:
        #   If multiple cookies satisfy the criteria above, they are ordered in
        #   the Cookie header such that those with more specific Path attributes
        #   precede those with less specific.  Ordering with respect to other
        #   attributes (e.g., Domain) is unspecified.
        @env[RACK_VARIABLE::REQUEST_COOKIE_HASH] =
          Hash[*Utils.parse_query(@env[RACK_VARIABLE::REQUEST_COOKIE_STRING], ';,').map {|k,v|
            [k, Array === v ? v.first : v]
          }.flatten]
      end
    end

    def xhr?
      @env[CGI_VARIABLE::HTTP_X_REQUESTED_WITH] == XML_HTTP_REQUEST
    end

    # Tries to return a remake of the original request URL as a string.
    def url
      url = scheme + "://"
      url << host

      if (scheme == HTTPS_SCHEME && port != 443) || (scheme == HTTP_SCHEME && port != 80)
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
      @env[CGI_VARIABLE::HTTP_ACCEPT_ENCODING].to_s.split(COMMA_DELIMTED_SPLITTER).map do |part|
        m = ACCEPT_ENCODING_SPLITTER.match(part) # From WEBrick

        if m
          [m[1], (m[2] || 1.0).to_f]
        else
          raise "Invalid value for Accept-Encoding: #{part.inspect}"
        end
      end
    end

    def ip
      if addr = @env[CGI_VARIABLE::HTTP_X_FORWARDED_FOR]
        (addr.split(',').grep(/\d\./).first || @env[CGI_VARIABLE::REMOTE_ADDR]).to_s.strip
      else
        @env[CGI_VARIABLE::REMOTE_ADDR]
      end
    end

    protected
      def parse_query(qs)
        Utils.parse_nested_query(qs)
      end

      def parse_multipart(env)
        Utils::Multipart.parse_multipart(env)
      end
  end
end
