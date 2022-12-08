# frozen_string_literal: true

require 'strscan'

require_relative '../utils'

module Rack
  module Multipart
    class MultipartPartLimitError < Errno::EMFILE; end

    class MultipartTotalPartLimitError < StandardError; end

    # Use specific error class when parsing multipart request
    # that ends early.
    class EmptyContentError < ::EOFError; end

    # Base class for multipart exceptions that do not subclass from
    # other exception classes for backwards compatibility.
    class Error < StandardError; end

    EOL = "\r\n"
    MULTIPART = %r|\Amultipart/.*boundary=\"?([^\";,]+)\"?|ni
    TOKEN = /[^\s()<>,;:\\"\/\[\]?=]+/
    CONDISP = /Content-Disposition:\s*#{TOKEN}\s*/i
    VALUE = /"(?:\\"|[^"])*"|#{TOKEN}/
    BROKEN = /^#{CONDISP}.*;\s*filename=(#{VALUE})/i
    MULTIPART_CONTENT_TYPE = /Content-Type: (.*)#{EOL}/ni
    MULTIPART_CONTENT_DISPOSITION = /Content-Disposition:[^:]*;\s*name=(#{VALUE})/ni
    MULTIPART_CONTENT_ID = /Content-ID:\s*([^#{EOL}]*)/ni
    # Updated definitions from RFC 2231
    ATTRIBUTE_CHAR = %r{[^ \x00-\x1f\x7f)(><@,;:\\"/\[\]?='*%]}
    ATTRIBUTE = /#{ATTRIBUTE_CHAR}+/
    SECTION = /\*[0-9]+/
    REGULAR_PARAMETER_NAME = /#{ATTRIBUTE}#{SECTION}?/
    REGULAR_PARAMETER = /(#{REGULAR_PARAMETER_NAME})=(#{VALUE})/
    EXTENDED_OTHER_NAME = /#{ATTRIBUTE}\*[1-9][0-9]*\*/
    EXTENDED_OTHER_VALUE = /%[0-9a-fA-F]{2}|#{ATTRIBUTE_CHAR}/
    EXTENDED_OTHER_PARAMETER = /(#{EXTENDED_OTHER_NAME})=(#{EXTENDED_OTHER_VALUE}*)/
    EXTENDED_INITIAL_NAME = /#{ATTRIBUTE}(?:\*0)?\*/
    EXTENDED_INITIAL_VALUE = /[a-zA-Z0-9\-]*'[a-zA-Z0-9\-]*'#{EXTENDED_OTHER_VALUE}*/
    EXTENDED_INITIAL_PARAMETER = /(#{EXTENDED_INITIAL_NAME})=(#{EXTENDED_INITIAL_VALUE})/
    EXTENDED_PARAMETER = /#{EXTENDED_INITIAL_PARAMETER}|#{EXTENDED_OTHER_PARAMETER}/
    DISPPARM = /;\s*(?:#{REGULAR_PARAMETER}|#{EXTENDED_PARAMETER})\s*/
    RFC2183 = /^#{CONDISP}(#{DISPPARM})+$/i

    class Parser
      BUFSIZE = 1_048_576
      TEXT_PLAIN = "text/plain"
      TEMPFILE_FACTORY = lambda { |filename, content_type|
        Tempfile.new(["RackMultipart", ::File.extname(filename.gsub("\0", '%00'))])
      }

      class BoundedIO # :nodoc:
        def initialize(io, content_length)
          @io             = io
          @content_length = content_length
          @cursor = 0
        end

        def read(size, outbuf = nil)
          return if @cursor >= @content_length

          left = @content_length - @cursor

          str = if left < size
                  @io.read left, outbuf
                else
                  @io.read size, outbuf
                end

          if str
            @cursor += str.bytesize
          else
            # Raise an error for mismatching content-length and actual contents
            raise EOFError, "bad content body"
          end

          str
        end
      end

      MultipartInfo = Struct.new :params, :tmp_files
      EMPTY         = MultipartInfo.new(nil, [])

      def self.parse_boundary(content_type)
        return unless content_type
        data = content_type.match(MULTIPART)
        return unless data
        data[1]
      end

      def self.parse(io, content_length, content_type, tmpfile, bufsize, qp)
        return EMPTY if 0 == content_length

        boundary = parse_boundary content_type
        return EMPTY unless boundary

        if boundary.length > 70
          # RFC 1521 Section 7.2.1 imposes a 70 character maximum for the boundary.
          # Most clients use no more than 55 characters.
          raise Error, "multipart boundary size too large (#{boundary.length} characters)"
        end

        io = BoundedIO.new(io, content_length) if content_length

        parser = new(boundary, tmpfile, bufsize, qp)
        parser.parse(io)

        parser.result
      end

      class Collector
        class MimePart < Struct.new(:body, :head, :filename, :content_type, :name)
          def get_data
            data = body
            if filename == ""
              # filename is blank which means no file has been selected
              return
            elsif filename
              body.rewind if body.respond_to?(:rewind)

              # Take the basename of the upload's original filename.
              # This handles the full Windows paths given by Internet Explorer
              # (and perhaps other broken user agents) without affecting
              # those which give the lone filename.
              fn = filename.split(/[\/\\]/).last

              data = { filename: fn, type: content_type,
                      name: name, tempfile: body, head: head }
            end

            yield data
          end
        end

        class BufferPart < MimePart
          def file?; false; end
          def close; end
        end

        class TempfilePart < MimePart
          def file?; true; end
          def close; body.close; end
        end

        include Enumerable

        def initialize(tempfile)
          @tempfile = tempfile
          @mime_parts = []
          @open_files = 0
        end

        def each
          @mime_parts.each { |part| yield part }
        end

        def on_mime_head(mime_index, head, filename, content_type, name)
          if filename
            body = @tempfile.call(filename, content_type)
            body.binmode if body.respond_to?(:binmode)
            klass = TempfilePart
            @open_files += 1
          else
            body = String.new
            klass = BufferPart
          end

          @mime_parts[mime_index] = klass.new(body, head, filename, content_type, name)

          check_part_limits
        end

        def on_mime_body(mime_index, content)
          @mime_parts[mime_index].body << content
        end

        def on_mime_finish(mime_index)
        end

        private

        def check_part_limits
          file_limit = Utils.multipart_file_limit
          part_limit = Utils.multipart_total_part_limit

          if file_limit && file_limit > 0
            if @open_files >= file_limit
              @mime_parts.each(&:close)
              raise MultipartPartLimitError, 'Maximum file multiparts in content reached'
            end
          end

          if part_limit && part_limit > 0
            if @mime_parts.size >= part_limit
              @mime_parts.each(&:close)
              raise MultipartTotalPartLimitError, 'Maximum total multiparts in content reached'
            end
          end
        end
      end

      attr_reader :state

      def initialize(boundary, tempfile, bufsize, query_parser)
        @query_parser   = query_parser
        @params         = query_parser.make_params
        @bufsize        = bufsize

        @state = :FAST_FORWARD
        @mime_index = 0
        @collector = Collector.new tempfile

        @sbuf = StringScanner.new("".dup)
        @body_regex = /(?:#{EOL}|\A)--#{Regexp.quote(boundary)}(?:#{EOL}|--)/m
        @rx_max_size = boundary.bytesize + 6 # (\r\n-- at start, either \r\n or -- at finish)
        @head_regex = /(.*?#{EOL})#{EOL}/m
      end

      def parse(io)
        outbuf = String.new
        read_data(io, outbuf)

        loop do
          status =
            case @state
            when :FAST_FORWARD
              handle_fast_forward
            when :CONSUME_TOKEN
              handle_consume_token
            when :MIME_HEAD
              handle_mime_head
            when :MIME_BODY
              handle_mime_body
            else # when :DONE
              return
            end

          read_data(io, outbuf) if status == :want_read
        end
      end

      def result
        @collector.each do |part|
          part.get_data do |data|
            tag_multipart_encoding(part.filename, part.content_type, part.name, data)
            @query_parser.normalize_params(@params, part.name, data)
          end
        end
        MultipartInfo.new @params.to_params_hash, @collector.find_all(&:file?).map(&:body)
      end

      private

      def dequote(str) # From WEBrick::HTTPUtils
        ret = (/\A"(.*)"\Z/ =~ str) ? $1 : str.dup
        ret.gsub!(/\\(.)/, "\\1")
        ret
      end

      def read_data(io, outbuf)
        content = io.read(@bufsize, outbuf)
        handle_empty_content!(content)
        @sbuf.concat(content)
      end

      # This handles the initial parser state.  We read until we find the starting
      # boundary, then we can transition to the next state. If we find the ending
      # boundary, this is an invalid multipart upload, but keep scanning for opening
      # boundary in that case. If no boundary found, we need to keep reading data
      # and retry. It's highly unlikely the initial read will not consume the
      # boundary.  The client would have to deliberately craft a response
      # with the opening boundary beyond the buffer size for that to happen.
      def handle_fast_forward
        while true
          case consume_boundary
          when :BOUNDARY
            # found opening boundary, transition to next state
            @state = :MIME_HEAD
            return
          when :END_BOUNDARY
            # invalid multipart upload, but retry for opening boundary
          else
            # no boundary found, keep reading data
            return :want_read
          end
        end
      end

      def handle_consume_token
        tok = consume_boundary
        # break if we're at the end of a buffer, but not if it is the end of a field
        @state = if tok == :END_BOUNDARY || (@sbuf.eos? && tok != :BOUNDARY)
          :DONE
        else
          :MIME_HEAD
        end
      end

      def handle_mime_head
        if @sbuf.scan_until(@head_regex)
          head = @sbuf[1]
          content_type = head[MULTIPART_CONTENT_TYPE, 1]
          if name = head[MULTIPART_CONTENT_DISPOSITION, 1]
            name = dequote(name)
          else
            name = head[MULTIPART_CONTENT_ID, 1]
          end

          filename = get_filename(head)

          if name.nil? || name.empty?
            name = filename || "#{content_type || TEXT_PLAIN}[]".dup
          end

          @collector.on_mime_head @mime_index, head, filename, content_type, name
          @state = :MIME_BODY
        else
          :want_read
        end
      end

      def handle_mime_body
        if (body_with_boundary = @sbuf.check_until(@body_regex)) # check but do not advance the pointer yet
          body = body_with_boundary.sub(/#{@body_regex}\z/m, '') # remove the boundary from the string
          @collector.on_mime_body @mime_index, body
          @sbuf.pos += body.length + 2 # skip \r\n after the content
          @state = :CONSUME_TOKEN
          @mime_index += 1
        else
          # Save what we have so far
          if @rx_max_size < @sbuf.rest_size
            delta = @sbuf.rest_size - @rx_max_size
            @collector.on_mime_body @mime_index, @sbuf.peek(delta)
            @sbuf.pos += delta
            @sbuf.string = @sbuf.rest
          end
          :want_read
        end
      end

      # Scan until the we find the start or end of the boundary.
      # If we find it, return the appropriate symbol for the start or
      # end of the boundary.  If we don't find the start or end of the
      # boundary, clear the buffer and return nil.
      def consume_boundary
        if read_buffer = @sbuf.scan_until(@body_regex)
          read_buffer.end_with?(EOL) ? :BOUNDARY : :END_BOUNDARY
        else
          @sbuf.terminate
          nil
        end
      end

      def get_filename(head)
        filename = nil
        case head
        when RFC2183
          params = Hash[*head.scan(DISPPARM).flat_map(&:compact)]

          if filename = params['filename*']
            encoding, _, filename = filename.split("'", 3)
          elsif filename = params['filename']
            filename = $1 if filename =~ /^"(.*)"$/
          end
        when BROKEN
          filename = $1
          filename = $1 if filename =~ /^"(.*)"$/
        end

        return unless filename

        if filename.scan(/%.?.?/).all? { |s| /%[0-9a-fA-F]{2}/.match?(s) }
          filename = Utils.unescape_path(filename)
        end

        filename.scrub!

        if filename !~ /\\[^\\"]/
          filename = filename.gsub(/\\(.)/, '\1')
        end

        if encoding
          filename.force_encoding ::Encoding.find(encoding)
        end

        filename
      end

      CHARSET = "charset"
      deprecate_constant :CHARSET

      def tag_multipart_encoding(filename, content_type, name, body)
        name = name.to_s
        encoding = Encoding::UTF_8

        name.force_encoding(encoding)

        return if filename

        if content_type
          list         = content_type.split(';')
          type_subtype = list.first
          type_subtype.strip!
          if TEXT_PLAIN == type_subtype
            rest = list.drop 1
            rest.each do |param|
              k, v = param.split('=', 2)
              k.strip!
              v.strip!
              v = v[1..-2] if v.start_with?('"') && v.end_with?('"')
              if k == "charset"
                encoding = begin
                  Encoding.find v
                rescue ArgumentError
                  Encoding::BINARY
                end
              end
            end
          end
        end

        name.force_encoding(encoding)
        body.force_encoding(encoding)
      end

      def handle_empty_content!(content)
        if content.nil? || content.empty?
          raise EmptyContentError
        end
      end
    end
  end
end
