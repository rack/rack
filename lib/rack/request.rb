require 'rack/utils'

module Rack
  class Request
    attr_reader :env
    
    def initialize(env)
      @env = env
    end

    def body;            @env["rack.input"]                       end
    def scheme;          @env["rack.url_scheme"]                  end
    def script_name;     @env["SCRIPT_NAME"].to_s                 end
    def path_info;       @env["PATH_INFO"].to_s                   end
    def host;            @env["HTTP_HOST"] || @env["SERVER_NAME"] end
    def port;            @env["SERVER_PORT"].to_i                 end
    def request_method;  @env["REQUEST_METHOD"]                   end
    def query_string;    @env["QUERY_STRING"].to_s                end

    def script_name=(s); @env["SCRIPT_NAME"] = s.to_s             end
    def path_info=(s);   @env["PATH_INFO"] = s.to_s               end

    def get?;            request_method == "GET"                  end
    def post?;           request_method == "POST"                 end
    def put?;            request_method == "PUT"                  end
    def delete?;         request_method == "DELETE"               end

    def GET
      if @env["rack.request.query_string"] == query_string
        @env["rack.request.query_hash"]
      else
        @env["rack.request.query_string"] = query_string
        @env["rack.request.query_hash"]   =
          Utils.parse_query(query_string)
      end
    end

    def POST
      if @env["rack.request.form_input"] == @env["rack.input"]
        @env["rack.request.form_hash"]
      else
        @env["rack.request.form_input"] = @env["rack.input"]
        @env["rack.request.form_vars"] = body.read
        @env["rack.request.form_hash"] =
          Utils.parse_query(@env["rack.request.form_vars"])
      end
    end

    def params
      self.GET.update(self.POST)
    end

    def cookies
      return {}  unless @env["HTTP_COOKIE"]

      if @env["rack.request.cookie_string"] == @env["HTTP_COOKIE"]
        @env["rack.request.cookie_hash"]
      else
        @env["rack.request.cookie_string"] = @env["HTTP_COOKIE"]
        # XXX sure?
        @env["rack.request.cookie_hash"] =
          Utils.parse_query(@env["rack.request.cookie_string"], ';,')
      end
    end

    def xhr?
      @env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    end

    def url
      url = scheme + "://"
      url << host

      if scheme == "https" && port != 443 ||
          scheme == "http" && port != 80
        url << ":#{port}"
      end

      url << script_name
      url << path_info

      unless query_string.empty?
        url << "?" << query_string
      end

      url
    end
  end
end
