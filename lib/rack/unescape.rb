# frozen_string_literal: true

require 'uri'
require 'cgi/escape'

module Rack
  module Unescape # :nodoc:
    private

    def unescape(s, encoding = Encoding::UTF_8)
      return URI.decode_www_form_component(s, encoding) unless s.instance_of?(String) && s.encoding.ascii_compatible?

      raise ArgumentError, "invalid %-encoding (#{s})" if /%(?!\h\h)/.match?(s)
      CGI.unescape(s, Encoding::BINARY).force_encoding(encoding)
    end
  end
end
