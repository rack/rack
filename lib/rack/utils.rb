module Rack
  module Utils
    # Performs URI escaping so that you can construct proper
    # query strings faster.  Use this rather than the cgi.rb
    # version since it's faster.  (Stolen from Camping).
    def escape(s)
      s.to_s.gsub(/([^ a-zA-Z0-9_.-]+)/n) {
        '%'+$1.unpack('H2'*$1.size).join('%').upcase
      }.tr(' ', '+') 
    end
    module_function :escape
    
    # Unescapes a URI escaped string. (Stolen from Camping).
    def unescape(s)
      s.tr('+', ' ').gsub(/((?:%[0-9a-fA-F]{2})+)/n){
        [$1.delete('%')].pack('H*')
      } 
    end
    module_function :unescape
    
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
    module_function :parse_query

    class HeaderHash < Hash
      def initialize(hash={})
        hash.each { |k, v| self[k] = v }
      end
      
      def to_hash
        {}.replace(self)
      end

      def [](k)
        super capitalize(k)
      end
      
      def []=(k, v)
        super capitalize(k), v
      end

      def capitalize(k)
        k.to_s.downcase.gsub(/^.|[-_\s]./) { |x| x.upcase }
      end
    end
  end
end
