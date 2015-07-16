module Rack
  # A multipart form data parser, adapted from IOWA.
  #
  # Usually, Rack::Request#POST takes care of calling this.
  module Multipart
    autoload :UploadedFile, 'rack/multipart/uploaded_file'
    autoload :Parser, 'rack/multipart/parser'
    autoload :Generator, 'rack/multipart/generator'

    EOL = "\r\n"
    MULTIPART_BOUNDARY = "AaB03x"
    MULTIPART = %r|\Amultipart/.*boundary=\"?([^\";,]+)\"?|ni
    TOKEN = /[^\s()<>,;:\\"\/\[\]?=]+/
    CONDISP = /Content-Disposition:\s*#{TOKEN}\s*/i
    VALUE = /"(?:\\"|[^"])*"|#{TOKEN}/
    BROKEN_QUOTED = /^#{CONDISP}.*;\sfilename="(.*?)"(?:\s*$|\s*;\s*#{TOKEN}=)/i
    BROKEN_UNQUOTED = /^#{CONDISP}.*;\sfilename=(#{TOKEN})/i
    MULTIPART_CONTENT_TYPE = /Content-Type: (.*)#{EOL}/ni
    MULTIPART_CONTENT_DISPOSITION = /Content-Disposition:.*\s+name="?([^\";]*)"?/ni
    MULTIPART_CONTENT_ID = /Content-ID:\s*([^#{EOL}]*)/ni
    # Updated definitions from RFC 2231
    ATTRIBUTE_CHAR = %r{[^ \t)(><@,;:\\"/\[\]?=]}
    ATTRIBUTE = /#{ATTRIBUTE_CHAR}+/
    SECTION = /\*0|\*\d+/
    REGULAR_PARAMETER_NAME = /#{ATTRIBUTE}#{SECTION}?/
    REGULAR_PARAMETER = /(#{REGULAR_PARAMETER_NAME})=(#{VALUE})/
    EXTENDED_OTHER_NAME = /#{ATTRIBUTE}\*[1-9][0-9]+\*/
    EXTENDED_OTHER_VALUE = /%[0-9a-fA-F]{2}|#{ATTRIBUTE_CHAR}/
    EXTENDED_OTHER_PARAMETER = /#{EXTENDED_OTHER_NAME}=#{EXTENDED_OTHER_VALUE}/
    EXTENDED_INITIAL_NAME = /#{ATTRIBUTE}(?:\*0)?\*/
    EXTENDED_INITIAL_VALUE = /(?:[a-zA-Z0-9\-]+)'(?:[a-zA-Z0-9\-]+)'(?:#{EXTENDED_OTHER_VALUE}+)/
    EXTENDED_INITIAL_PARAMETER = /#{EXTENDED_INITIAL_NAME}=#{EXTENDED_INITIAL_VALUE}/
    EXTENDED_PARAMETER = /#{EXTENDED_INITIAL_PARAMETER}|#{EXTENDED_OTHER_PARAMETER}/
    DISPPARM = /;\s*#{REGULAR_PARAMETER}|#{EXTENDED_PARAMETER}/
    RFC2183 = /#{CONDISP}(#{DISPPARM})+/i

    class << self
      def parse_multipart(env, params = Rack::Utils.default_query_parser)
        Parser.create(env, params).parse
      end

      def build_multipart(params, first = true)
        Generator.new(params, first).dump
      end
    end

  end
end
