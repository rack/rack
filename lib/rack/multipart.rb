# frozen_string_literal: true

require_relative 'constants'
require_relative 'utils'

require_relative 'multipart/parser'
require_relative 'multipart/generator'

module Rack
  # A multipart form data parser, adapted from IOWA.
  #
  # Usually, Rack::Request#POST takes care of calling this.
  module Multipart
    MULTIPART_BOUNDARY = "AaB03x"

    class << self
      def parse_multipart(env, params = Rack::Utils.default_query_parser)
        io = env[RACK_INPUT]

        if content_length = env['CONTENT_LENGTH']
          content_length = content_length.to_i
        end

        content_type = env['CONTENT_TYPE']

        tempfile = env[RACK_MULTIPART_TEMPFILE_FACTORY] || Parser::TEMPFILE_FACTORY
        bufsize = env[RACK_MULTIPART_BUFFER_SIZE] || Parser::BUFSIZE

        info = Parser.parse(io, content_length, content_type, tempfile, bufsize, params)
        env[RACK_TEMPFILES] = info.tmp_files

        return info.params
      end

      def extract_multipart(request, params = Rack::Utils.default_query_parser)
        parse_multipart(request.env)
      end

      def build_multipart(params, first = true)
        Generator.new(params, first).dump
      end
    end
  end
end
