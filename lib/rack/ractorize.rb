# frozen_string_literal: true

module Rack
  Headers::KNOWN_HEADERS.freeze

  Ractor.make_shareable(Multipart::Parser::TEMPFILE_FACTORY)
  Multipart::Parser::REENCODE_DUMMY_ENCODINGS.freeze

  Ractor.make_shareable(Request.ip_filter)
  Request.forwarded_priority.freeze
  Request.x_forwarded_proto_priority.freeze

  Request::Helpers::FORM_DATA_MEDIA_TYPES.freeze
  Request::Helpers::PARSEABLE_DATA_MEDIA_TYPES.freeze
  Request::Helpers::DEFAULT_PORTS.freeze

  Utils::SYMBOL_TO_STATUS_CODE.freeze
  Utils::HTTP_STATUS_CODES.freeze

  QueryParser::COMMON_SEP.freeze

  Directory::FILESIZE_FORMAT.each(&:freeze).freeze

  Files::ALLOWED_VERBS.freeze
  Files::ALLOW_HEADER.freeze

  Mime::MIME_TYPES.freeze
end
