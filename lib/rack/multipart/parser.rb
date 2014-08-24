require 'rack/utils'

module Rack
  module Multipart
    class MultipartPartLimitError < Errno::EMFILE; end

    class Parser
      BUFSIZE = 16384
      TEXT_PLAIN = "text/plain"

      DUMMY = Struct.new(:parse).new

      def self.create(env, query_parser)
        return DUMMY unless env['CONTENT_TYPE'] =~ MULTIPART

        io = env['rack.input']
        io.rewind

        content_length = env['CONTENT_LENGTH']
        content_length = content_length.to_i if content_length

        tempfile = env['rack.multipart.tempfile_factory'] ||
          lambda { |filename, content_type| Tempfile.new(["RackMultipart", ::File.extname(filename)]) }
        bufsize = env['rack.multipart.buffer_size'] || BUFSIZE

        new($1, io, content_length, env, tempfile, bufsize, query_parser)
      end

      def initialize(boundary, io, content_length, env, tempfile, bufsize, query_parser)
        @buf            = "".force_encoding(Encoding::ASCII_8BIT)

        @query_parser   = query_parser
        @params         = query_parser.make_params
        @boundary       = "--#{boundary}"
        @io             = io
        @content_length = content_length
        @boundary_size  = @boundary.bytesize + EOL.size
        @env = env
        @tempfile       = tempfile
        @bufsize        = bufsize

        if @content_length
          @content_length -= @boundary_size
        end

        @rx = /(?:#{EOL})?#{Regexp.quote(@boundary)}(#{EOL}|--)/n
        @full_boundary = @boundary + EOL
      end

      def parse
        fast_forward_to_first_boundary

        opened_files = 0
        loop do

          head, filename, content_type, name, body =
            get_current_head_and_filename_and_content_type_and_name_and_body

          if Utils.multipart_part_limit > 0
            opened_files += 1 if filename
            raise MultipartPartLimitError, 'Maximum file multiparts in content reached' if opened_files >= Utils.multipart_part_limit
          end

          # Save the rest.
          if i = @buf.index(rx)
            body << @buf.slice!(0, i)
            @buf.slice!(0, @boundary_size+2)

            @content_length = -1  if $1 == "--"
          end

          get_data(filename, body, content_type, name, head) do |data|
            tag_multipart_encoding(filename, content_type, name, data)

            @query_parser.normalize_params(@params, name, data)
          end

          # break if we're at the end of a buffer, but not if it is the end of a field
          break if (@buf.empty? && $1 != EOL) || @content_length == -1
        end

        @io.rewind

        @params.to_params_hash
      end

      private
      def full_boundary; @full_boundary; end

      def rx; @rx; end

      def fast_forward_to_first_boundary
        loop do
          content = @io.read(@bufsize)
          handle_empty_content!(content) and return ""

          @buf << content

          while @buf.gsub!(/\A([^\n]*\n)/, '')
            read_buffer = $1
            return if read_buffer == full_boundary
          end

          raise EOFError, "bad content body" if @buf.bytesize >= @bufsize
        end
      end

      def get_current_head_and_filename_and_content_type_and_name_and_body
        head = nil
        body = ''.force_encoding(Encoding::ASCII_8BIT)

        filename = content_type = name = nil

        until head && @buf =~ rx
          if !head && i = @buf.index(EOL+EOL)
            head = @buf.slice!(0, i+2) # First \r\n

            @buf.slice!(0, 2)          # Second \r\n

            content_type = head[MULTIPART_CONTENT_TYPE, 1]
            name = head[MULTIPART_CONTENT_DISPOSITION, 1] || head[MULTIPART_CONTENT_ID, 1]

            filename = get_filename(head)

            if name.nil? || name.empty?
              name = filename || "#{content_type || TEXT_PLAIN}[]"
            end

            if filename
              (@env['rack.tempfiles'] ||= []) << body = @tempfile.call(filename, content_type)
              body.binmode if body.respond_to?(:binmode)
            end

            next
          end

          # Save the read body part.
          if head && (@boundary_size+4 < @buf.size)
            body << @buf.slice!(0, @buf.size - (@boundary_size+4))
          end

          content = @io.read(@content_length && @bufsize >= @content_length ? @content_length : @bufsize)
          handle_empty_content!(content) and break

          @buf << content
          @content_length -= content.size if @content_length
        end

        [head, filename, content_type, name, body]
      end

      def get_filename(head)
        filename = nil
        case head
        when BROKEN_QUOTED, BROKEN_UNQUOTED
          filename = $1
        when RFC2183
          params = Hash[head.scan(DISPPARM)]
          filename = params['filename']
          filename ||= params['filename*']
          filename = $1 if filename and filename =~ /^"(.*)"$/
        end

        return unless filename

        if filename.scan(/%.?.?/).all? { |s| s =~ /%[0-9a-fA-F]{2}/ }
          filename = Utils.unescape(filename)
        end

        scrub_filename(filename)

        if filename !~ /\\[^\\"]/
          filename = filename.gsub(/\\(.)/, '\1')
        end
        
        encoding, locale, name = filename.split("'",3)

        if locale.nil? && name.nil?
          name = encoding
        else
          name.force_encoding ::Encoding.find(encoding)
        end
      end

      def scrub_filename(filename)
        unless filename.valid_encoding?
          # FIXME: this force_encoding is for Ruby 2.0 and 1.9 support.
          # We can remove it after they are dropped
          filename.force_encoding(Encoding::ASCII_8BIT)
          filename.encode!(:invalid => :replace, :undef => :replace)
        end
      end

      CHARSET   = "charset"

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
            rest         = list.drop 1
            rest.each do |param|
              k,v = param.split('=', 2)
              k.strip!
              v.strip!
              encoding = Encoding.find v if k == CHARSET
            end
          end
        end

        name.force_encoding(encoding)
        body.force_encoding(encoding)
      end


      def get_data(filename, body, content_type, name, head)
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
          filename = filename.split(/[\/\\]/).last

          data = {:filename => filename, :type => content_type,
                  :name => name, :tempfile => body, :head => head}
        elsif !filename && content_type && body.is_a?(IO)
          body.rewind

          # Generic multipart cases, not coming from a form
          data = {:type => content_type,
                  :name => name, :tempfile => body, :head => head}
        elsif !filename && data.empty?
          return
        end

        yield data
      end

      def handle_empty_content!(content)
        if content.nil? || content.empty?
          # Raise an error for mismatching Content-Length and actual contents
          raise EOFError, "bad content body" if @content_length.to_i > 0

          # In case we receive a POST request with empty body, reset @content_length
          # and return empty string
          @content_length = 0
          @buf = ""

          return true
        end
      end
    end
  end
end
