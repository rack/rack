# frozen_string_literal: true

require_relative 'constants'
require_relative 'utils'

module Rack
  # A multipart form data parser, adapted from IOWA.
  #
  # Usually, Rack::Request#POST takes care of calling this.
  module Multipart
    MULTIPART_BOUNDARY = "AaB03x"

    class << self
      def parse_multipart(env, params = Rack::Utils.default_query_parser)
        extract_multipart Rack::Request.new(env), params
      end

      def extract_multipart(req, params = Rack::Utils.default_query_parser)
        io = req.get_header(RACK_INPUT)
        content_length = req.content_length
        content_length = content_length.to_i if content_length

        tempfile = req.get_header(RACK_MULTIPART_TEMPFILE_FACTORY) || Parser::TEMPFILE_FACTORY
        bufsize = req.get_header(RACK_MULTIPART_BUFFER_SIZE) || Parser::BUFSIZE

        info = Parser.parse io, content_length, req.get_header('CONTENT_TYPE'), tempfile, bufsize, params
        req.set_header(RACK_TEMPFILES, info.tmp_files)
        info.params
      end

      def build_multipart(params, first = true)
        Generator.new(params, first).dump
      end
    end
  end
end

require_relative 'request' unless defined?(Rack::Request)
require_relative 'multipart/parser'
require_relative 'multipart/uploaded_file' unless defined?(Rack::Multipart::UploadedFile)
require_relative 'multipart/generator' unless defined?(Rack::Multipart::Generator)
