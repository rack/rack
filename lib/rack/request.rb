require 'rack/utils'

module Rack
  class Request
    attr_reader :env
    
    def initialize(env)
      @env = env
    end

    def body;        @env["rack.input"]                       end
    def scheme;      @env["rack.url_scheme"]                  end
    def script_name; @env["SCRIPT_NAME"].to_s                 end
    def path_info;   @env["PATH_INFO"].to_s                   end
    def host;        @env["HTTP_HOST"] || @env["SERVER_NAME"] end
    def port;        @env["SERVER_PORT"].to_i                 end
    def method;      @env["REQUEST_METHOD"]                   end

    def script_name=(s); @env["SCRIPT_NAME"] = s.to_s         end
    def path_info=(s);   @env["PATH_INFO"] = s.to_s           end

    def get?;    method == "GET"    end
    def post?;   method == "POST"   end
    def put?;    method == "PUT"    end
    def delete?; method == "DELETE" end

    def GET
      Utils.parse_query(@env["QUERY_STRING"])
    end

    def POST
      @env["rack.request.formvars"] ||= body.read
      Utils.parse_query(@env["rack.request.formvars"])
    end

    def params
      self.GET.update(self.POST)
    end

    def cookies
      Utils.parse_query(@env["HTTP_COOKIE"], ';,')   # XXX sure?
    end

    def xhr?
      @env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    end
  end
end
