module Rack
  class Request
    def initialize(env)
      @env = env
    end

    def body;        @env["rack.input"]                       end
    def scheme;      @env["rack.url_scheme"]                  end
    def method;      @env["REQUEST_METHOD"]                   end
    def script_name; @env["SCRIPT_NAME"].to_s                 end
    def path_info;   @env["PATH_INFO"].to_s                   end
    def host;        @env["HTTP_HOST"] || @env["SERVER_NAME"] end
    def path_info;   @env["PATH_INFO"].to_s                   end
    def port;        @env["SERVER_PORT"].to_i                 end

    def GET
      parse_query(@env["QUERY_STRING"])
    end

    def POST
      @env["rack.request.formvars"] ||= body.read
      parse_query(@env["rack.request.formvars"])
    end

    def params
      self.GET.update(self.POST)
    end

    def cookies
      parse_query(@env["HTTP_COOKIE"], ';,')
    end

    def xhr?
      @env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    end
    

    # Performs URI escaping so that you can construct proper
    # query strings faster.  Use this rather than the cgi.rb
    # version since it's faster.  (Stolen from Camping).
    def escape(s)
      s.to_s.gsub(/([^ a-zA-Z0-9_.-]+)/n) {
        '%'+$1.unpack('H2'*$1.size).join('%').upcase
      }.tr(' ', '+') 
    end
    
    # Unescapes a URI escaped string. (Stolen from Camping).
    def unescape(s)
      s.tr('+', ' ').gsub(/((?:%[0-9a-fA-F]{2})+)/n){
        [$1.delete('%')].pack('H*')
      } 
    end
    
    # Stolen from Mongrel:
    # Parses a query string by breaking it up at the '&' 
    # and ';' characters.  You can also use this to parse
    # cookies by changing the characters used in the second
    # parameter (which defaults to '&;'.
    
    def parse_query(qs, d = '&;')
      params = {}
      (qs||'').split(/[#{d}] */n).inject(params) { |h,p|
        k, v=unescape(p).split('=',2)
        if cur = params[k]
          if cur.class == Array
            params[k] << v
          else
            params[k] = [cur, v]
          end
        else
          params[k] = v
        end
      }
      
      return params
    end    
  end
end
