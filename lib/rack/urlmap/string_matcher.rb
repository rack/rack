module Rack
  class URLMap
    # Rack::URLMap::StringMatcher encapsulates logic for for matching urls.
    #.
    # StringMatcher provides three main methods in the public interface:
    #
    # +priorities+:: to order matchers according to URLMap specs.
    # +matches?+:: to check if related mapping is applicable.
    # +rest+:: to get a 'wildcarded' part of the requested address.
    class StringMatcher
      LOWEST_PRIORITY = 1.0 / 0.0

      attr_reader :location, :host

      def initialize(address)
        extract address
      end

      # Priority of the matcher.
      #
      # The higher the priority the lower the values in the array.
      # (that's because sort_by sorts in ascending order)
      def priorities
        [host ? -host.size : LOWEST_PRIORITY, -location.size]
      end

      def matches?(server_name, server_port, http_host, path)
        match_host(server_name, server_port, http_host) && match_path(path)
      end

      # Gives rest of the path (everything to the right from location's end)
      # I.e. if requested address is /foo/bar, and matcher matches /foo, than
      # rest will return /bar.
      #
      # If path matches +wildcarded_address+ regex, match result will always be an array
      # of two elements, first one -- full match, second one -- capture group
      # (always string, maybe empty).
      # Otherwise it will be just an empty array.
      #
      # Therefore, result of the function will be nil, if there is no match,
      # and some string otherwise.
      def rest(path)
        Array(wildcarded_address.match path.to_s)[1]
      end

      private

      def extract(address)
        if address =~ %r{\Ahttps?://(.*?)(/.*)}
          @host, @location = $1, $2
        else
          @host, @location = nil, address
        end

        unless @location[0] == ?/
          raise ArgumentError, "paths need to start with /"
        end

        @location = @location.chomp('/')
      end

      def wildcarded_address
        @wildcarder_address ||= Regexp.new("^#{Regexp.quote(@location).gsub('/', '/+')}(.*)", nil, 'n')
      end

      def match_host(server_name, server_port, http_host)
        http_host == @host || server_name == @host \
          || (!@host && (http_host == server_name || http_host == server_name+':'+server_port))
      end

      def match_path(path)
        memo = rest path
        return false if memo.nil?
        true if memo.empty? || memo[0] == ?/
      end

    end
  end
end
