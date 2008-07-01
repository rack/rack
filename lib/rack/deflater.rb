require "zlib"

module Rack

class Deflater
  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, body = @app.call(env)

    request  = Request.new(env)
    encoding = Utils.select_best_encoding(%w(deflate identity), request.accept_encoding)

    case encoding
    when "deflate"
      [status, headers.merge("Content-Encoding" => "deflate"), self.class.deflate(body)]
    when "identity"
      [status, headers, body]
    when nil
      # TODO: Add Content-Type
      [406, {}, "..."]
    end
  end

  # Loosely based on Mongrel's Deflate handler
  def self.deflate(body)
    deflater = Zlib::Deflate.new(
      Zlib::DEFAULT_COMPRESSION,
      # drop the zlib header which causes both Safari and IE to choke
      -Zlib::MAX_WBITS,
      Zlib::DEF_MEM_LEVEL,
      Zlib::DEFAULT_STRATEGY)

    # TODO: Add streaming
    # TODO: Consider all part types
    body.each { |part| deflater << part }

    return deflater.finish
  end
end

end
