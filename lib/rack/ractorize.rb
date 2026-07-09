# frozen_string_literal: true

module Rack
  file_loaded = ->(const) { const_defined?(const, false) && !autoload?(const) }

  if file_loaded.(:Headers)
    Headers::KNOWN_HEADERS.freeze
  end

  if file_loaded.(:Multipart)
    Ractor.make_shareable(Multipart::Parser::TEMPFILE_FACTORY)
    Multipart::Parser::REENCODE_DUMMY_ENCODINGS.freeze
  end

  if file_loaded.(:Request)
    Ractor.make_shareable(Request.ip_filter)
    Request.forwarded_priority.freeze
    Request.x_forwarded_proto_priority.freeze

    Request::Helpers::FORM_DATA_MEDIA_TYPES.freeze
    Request::Helpers::PARSEABLE_DATA_MEDIA_TYPES.freeze
    Request::Helpers::DEFAULT_PORTS.freeze
  end

  if file_loaded.(:Utils)
    Utils::SYMBOL_TO_STATUS_CODE.freeze
    Utils::HTTP_STATUS_CODES.freeze
  end

  if file_loaded.(:QueryParser)
    QueryParser::COMMON_SEP.freeze
  end

  if file_loaded.(:Directory)
    Directory::FILESIZE_FORMAT.each(&:freeze).freeze
  end

  if file_loaded.(:Files)
    Files::ALLOWED_VERBS.freeze
    Files::ALLOW_HEADER.freeze
  end

  if file_loaded.(:Mime)
    Mime::MIME_TYPES.freeze
  end

  if file_loaded.(:ShowExceptions)
    Ractor.make_shareable(ShowExceptions::TEMPLATE)
  end

  if file_loaded.(:TempfileReaper)
    Ractor.make_shareable(TempfileReaper.const_get(:RESPONSE_FINISHED_HANDLER))
  end
end
