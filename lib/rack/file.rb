require 'time'
require 'rack/utils'
require 'rack/mime'

module Rack
  # Rack::File serves files below the +root+ directory given, according to the
  # path info of the Rack request.
  # e.g. when Rack::File.new("/etc") is used, you can access 'passwd' file
  # as http://localhost:9292/passwd
  #
  # Handlers can detect if bodies are a Rack::File, and use mechanisms
  # like sendfile on the +path+.

  class File
    attr_accessor :root
    attr_accessor :path

    alias :to_path :path

    def initialize(root)
      @root = root
    end

    def call(env)
      dup._call(env)
    end

    F = ::File

    def _call(env)
      @path_info = Utils.unescape(env["PATH_INFO"])
      return fail(403, "Forbidden")  if @path_info.include? ".."

      @path = F.join(@root, @path_info)

      available = begin
        F.file?(@path) && F.readable?(@path)
      rescue SystemCallError
        false
      end

      if available
        serving(env)
      else
        fail(404, "File not found: #{@path_info}")
      end
    end

    def serving(env)
      # NOTE:
      #   We check via File::size? whether this file provides size info
      #   via stat (e.g. /proc files often don't), otherwise we have to
      #   figure it out by reading the whole file into memory.
      size = F.size?(@path) || Utils.bytesize(F.read(@path))

      response = [
        200,
        {
          "Last-Modified"  => F.mtime(@path).httpdate,
          "Content-Type"   => Mime.mime_type(F.extname(@path), 'text/plain')
        },
        self
      ]

      ranges = self.class.byte_ranges(env, size)
      if ranges.nil? || ranges.length > 1
        # No ranges, or multiple ranges (which we don't support):
        # TODO: Support multiple byte-ranges
        response[0] = 200
        @range = 0..size-1
      elsif ranges.empty?
        # Unsatisfiable. Return error, and file size:
        response = fail(416, "Byte range unsatisfiable")
        response[1]["Content-Range"] = "bytes */#{size}"
        return response
      else
        # Partial content:
        @range = ranges[0]
        response[0] = 206
        response[1]["Content-Range"]  = "bytes #{@range.begin}-#{@range.end}/#{size}"
        size = @range.end - @range.begin + 1
      end

      response[1]["Content-Length"] = size.to_s
      response
    end

    def each
      F.open(@path, "rb") do |file|
        file.seek(@range.begin)
        remaining_len = @range.end-@range.begin+1
        while remaining_len > 0
          part = file.read([8192, remaining_len].min)
          break unless part
          remaining_len -= part.length

          yield part
        end
      end
    end

    # Parses the "Range:" header, if present, into an array of Range objects.
    # Returns nil if the header is missing or syntactically invalid.
    # Returns an empty array if none of the ranges are satisfiable.
    def self.byte_ranges(env, size)
      # See <http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.35>
      http_range = env['HTTP_RANGE']
      return nil unless http_range
      ranges = []
      http_range.split(/,\s*/).each do |range_spec|
        matches = range_spec.match(/bytes=(\d*)-(\d*)/)
        return nil  unless matches
        r0,r1 = matches[1], matches[2]
        if r0.empty?
          return nil  if r1.empty?
          # suffix-byte-range-spec, represents trailing suffix of file
          r0 = [size - r1.to_i, 0].max
          r1 = size - 1
        else
          r0 = r0.to_i
          if r1.empty?
            r1 = size - 1
          else
            r1 = r1.to_i
            return nil  if r1 < r0  # backwards range is syntactically invalid
            r1 = size-1  if r1 >= size
          end
        end
        ranges << (r0..r1)  if r0 <= r1
      end
      ranges
    end

    private

    def fail(status, body)
      body += "\n"
      [
        status,
        {
          "Content-Type" => "text/plain",
          "Content-Length" => body.size.to_s,
          "X-Cascade" => "pass"
        },
        [body]
      ]
    end

  end
end
