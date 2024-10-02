# frozen_string_literal: true

require 'forwardable'
require 'uri'

require_relative 'constants'
require_relative 'utils'

module Rack
  # Rack::Lint validates your application and the requests and
  # responses according to the Rack spec.

  class Lint
    REQUEST_PATH_ORIGIN_FORM = /\A\/[^#]*\z/
    REQUEST_PATH_ABSOLUTE_FORM = /\A#{Utils::URI_PARSER.make_regexp}\z/
    REQUEST_PATH_AUTHORITY_FORM = /\A[^\/:]+:\d+\z/
    REQUEST_PATH_ASTERISK_FORM = '*'

    def initialize(app)
      @app = app
    end

    # :stopdoc:

    class LintError < RuntimeError; end
    # AUTHORS: n.b. The trailing whitespace between paragraphs is important and
    # should not be removed. The whitespace creates paragraphs in the RDoc
    # output.
    #
    ## This specification aims to formalize the Rack protocol. You
    ## can (and should) use Rack::Lint to enforce it.
    ##
    ## When you develop middleware, be sure to add a Lint before and
    ## after to catch all mistakes.
    ##
    ## = Rack applications
    ##
    ## A Rack application is a Ruby object (not a class) that
    ## responds to +call+.
    def call(env = nil)
      Wrapper.new(@app, env).response
    end

    class Wrapper
      def initialize(app, env)
        @app = app
        @env = env
        @response = nil
        @head_request = false

        @status = nil
        @headers = nil
        @body = nil
        @invoked = nil
        @content_length = nil
        @closed = false
        @size = 0
      end

      def response
        ## It takes exactly one argument, the *environment*
        raise LintError, "No env given" unless @env
        check_environment(@env)

        ## and returns a non-frozen Array of exactly three values:
        @response = @app.call(@env)
        raise LintError, "response is not an Array, but #{@response.class}" unless @response.kind_of? Array
        raise LintError, "response is frozen" if @response.frozen?
        raise LintError, "response array has #{@response.size} elements instead of 3" unless @response.size == 3

        @status, @headers, @body = @response
        ## The *status*,
        check_status(@status)

        ## the *headers*,
        check_headers(@headers)

        hijack_proc = check_hijack_response(@headers, @env)
        if hijack_proc
          @headers[RACK_HIJACK] = hijack_proc
        end

        ## and the *body*.
        check_content_type_header(@status, @headers)
        check_content_length_header(@status, @headers)
        check_rack_protocol_header(@status, @headers)
        @head_request = @env[REQUEST_METHOD] == HEAD

        @lint = (@env['rack.lint'] ||= []) << self

        if (@env['rack.lint.body_iteration'] ||= 0) > 0
          raise LintError, "Middleware must not call #each directly"
        end

        return [@status, @headers, self]
      end

      ##
      ## == The Environment
      ##
      def check_environment(env)
        ## The environment must be an unfrozen instance of Hash that includes
        ## CGI-like headers. The Rack application is free to modify the
        ## environment.
        raise LintError, "env #{env.inspect} is not a Hash, but #{env.class}" unless env.kind_of? Hash
        raise LintError, "env should not be frozen, but is" if env.frozen?

        ##
        ## The environment is required to include these variables
        ## (adopted from {PEP 333}[https://peps.python.org/pep-0333/]), except when they'd be empty, but see
        ## below.

        ## <tt>REQUEST_METHOD</tt>:: The HTTP request method, such as
        ##                           "GET" or "POST". This cannot ever
        ##                           be an empty string, and so is
        ##                           always required.

        ## <tt>SCRIPT_NAME</tt>:: The initial portion of the request
        ##                        URL's "path" that corresponds to the
        ##                        application object, so that the
        ##                        application knows its virtual
        ##                        "location". This may be an empty
        ##                        string, if the application corresponds
        ##                        to the "root" of the server.

        ## <tt>PATH_INFO</tt>:: The remainder of the request URL's
        ##                      "path", designating the virtual
        ##                      "location" of the request's target
        ##                      within the application. This may be an
        ##                      empty string, if the request URL targets
        ##                      the application root and does not have a
        ##                      trailing slash. This value may be
        ##                      percent-encoded when originating from
        ##                      a URL.

        ## <tt>QUERY_STRING</tt>:: The portion of the request URL that
        ##                         follows the <tt>?</tt>, if any. May be
        ##                         empty, but is always required!

        ## <tt>SERVER_NAME</tt>:: When combined with <tt>SCRIPT_NAME</tt> and
        ##                        <tt>PATH_INFO</tt>, these variables can be
        ##                        used to complete the URL. Note, however,
        ##                        that <tt>HTTP_HOST</tt>, if present,
        ##                        should be used in preference to
        ##                        <tt>SERVER_NAME</tt> for reconstructing
        ##                        the request URL.
        ##                        <tt>SERVER_NAME</tt> can never be an empty
        ##                        string, and so is always required.

        ## <tt>SERVER_PORT</tt>:: An optional +Integer+ which is the port the
        ##                        server is running on. Should be specified if
        ##                        the server is running on a non-standard port.

        ## <tt>SERVER_PROTOCOL</tt>:: A string representing the HTTP version used
        ##                            for the request.

        ## <tt>HTTP_</tt> Variables:: Variables corresponding to the
        ##                            client-supplied HTTP request
        ##                            headers (i.e., variables whose
        ##                            names begin with <tt>HTTP_</tt>). The
        ##                            presence or absence of these
        ##                            variables should correspond with
        ##                            the presence or absence of the
        ##                            appropriate HTTP header in the
        ##                            request. See
        ##                            {RFC3875 section 4.1.18}[https://tools.ietf.org/html/rfc3875#section-4.1.18]
        ##                            for specific behavior.

        ## In addition to this, the Rack environment must include these
        ## Rack-specific variables:

        ## <tt>rack.url_scheme</tt>:: +http+ or +https+, depending on the
        ##                            request URL.

        ## <tt>rack.input</tt>:: See below, the input stream.

        ## <tt>rack.errors</tt>:: See below, the error stream.

        ## <tt>rack.hijack?</tt>:: See below, if present and true, indicates
        ##                         that the server supports partial hijacking.

        ## <tt>rack.hijack</tt>:: See below, if present, an object responding
        ##                        to +call+ that is used to perform a full
        ##                        hijack.

        ## <tt>rack.protocol</tt>:: An optional +Array+ of +String+, containing
        ##                          the protocols advertised by the client in
        ##                          the +upgrade+ header (HTTP/1) or the
        ##                          +:protocol+ pseudo-header (HTTP/2).
        if protocols = @env['rack.protocol']
          unless protocols.is_a?(Array) && protocols.all?{|protocol| protocol.is_a?(String)}
            raise LintError, "rack.protocol must be an Array of Strings"
          end
        end

        ## Additional environment specifications have approved to
        ## standardized middleware APIs. None of these are required to
        ## be implemented by the server.

        ## <tt>rack.session</tt>:: A hash-like interface for storing
        ##                         request session data.
        ##                         The store must implement:
        if session = env[RACK_SESSION]
          ##                         store(key, value)         (aliased as []=);
          unless session.respond_to?(:store) && session.respond_to?(:[]=)
            raise LintError, "session #{session.inspect} must respond to store and []="
          end

          ##                         fetch(key, default = nil) (aliased as []);
          unless session.respond_to?(:fetch) && session.respond_to?(:[])
            raise LintError, "session #{session.inspect} must respond to fetch and []"
          end

          ##                         delete(key);
          unless session.respond_to?(:delete)
            raise LintError, "session #{session.inspect} must respond to delete"
          end

          ##                         clear;
          unless session.respond_to?(:clear)
            raise LintError, "session #{session.inspect} must respond to clear"
          end

          ##                         to_hash (returning unfrozen Hash instance);
          unless session.respond_to?(:to_hash) && session.to_hash.kind_of?(Hash) && !session.to_hash.frozen?
            raise LintError, "session #{session.inspect} must respond to to_hash and return unfrozen Hash instance"
          end
        end

        ## <tt>rack.logger</tt>:: A common object interface for logging messages.
        ##                        The object must implement:
        if logger = env[RACK_LOGGER]
          ##                         info(message, &block)
          unless logger.respond_to?(:info)
            raise LintError, "logger #{logger.inspect} must respond to info"
          end

          ##                         debug(message, &block)
          unless logger.respond_to?(:debug)
            raise LintError, "logger #{logger.inspect} must respond to debug"
          end

          ##                         warn(message, &block)
          unless logger.respond_to?(:warn)
            raise LintError, "logger #{logger.inspect} must respond to warn"
          end

          ##                         error(message, &block)
          unless logger.respond_to?(:error)
            raise LintError, "logger #{logger.inspect} must respond to error"
          end

          ##                         fatal(message, &block)
          unless logger.respond_to?(:fatal)
            raise LintError, "logger #{logger.inspect} must respond to fatal"
          end
        end

        ## <tt>rack.multipart.buffer_size</tt>:: An Integer hint to the multipart parser as to what chunk size to use for reads and writes.
        if bufsize = env[RACK_MULTIPART_BUFFER_SIZE]
          unless bufsize.is_a?(Integer) && bufsize > 0
            raise LintError, "rack.multipart.buffer_size must be an Integer > 0 if specified"
          end
        end

        ## <tt>rack.multipart.tempfile_factory</tt>:: An object responding to #call with two arguments, the filename and content_type given for the multipart form field, and returning an IO-like object that responds to #<< and optionally #rewind. This factory will be used to instantiate the tempfile for each multipart form file upload field, rather than the default class of Tempfile.
        if tempfile_factory = env[RACK_MULTIPART_TEMPFILE_FACTORY]
          raise LintError, "rack.multipart.tempfile_factory must respond to #call" unless tempfile_factory.respond_to?(:call)
          env[RACK_MULTIPART_TEMPFILE_FACTORY] = lambda do |filename, content_type|
            io = tempfile_factory.call(filename, content_type)
            raise LintError, "rack.multipart.tempfile_factory return value must respond to #<<" unless io.respond_to?(:<<)
            io
          end
        end

        ## The server or the application can store their own data in the
        ## environment, too.  The keys must contain at least one dot,
        ## and should be prefixed uniquely.  The prefix <tt>rack.</tt>
        ## is reserved for use with the Rack core distribution and other
        ## accepted specifications and must not be used otherwise.
        ##
        %w[REQUEST_METHOD SERVER_NAME QUERY_STRING SERVER_PROTOCOL rack.errors].each do |header|
          raise LintError, "env missing required key #{header}" unless env.include? header
        end

        ## The <tt>SERVER_PORT</tt> must be an Integer if set.
        server_port = env["SERVER_PORT"]
        unless server_port.nil? || (Integer(server_port) rescue false)
          raise LintError, "env[SERVER_PORT] is not an Integer"
        end

        ## The <tt>SERVER_NAME</tt> must be a valid authority as defined by RFC7540.
        unless (URI.parse("http://#{env[SERVER_NAME]}/") rescue false)
          raise LintError, "#{env[SERVER_NAME]} must be a valid authority"
        end

        ## The <tt>HTTP_HOST</tt> must be a valid authority as defined by RFC7540.
        unless (URI.parse("http://#{env[HTTP_HOST]}/") rescue false)
          raise LintError, "#{env[HTTP_HOST]} must be a valid authority"
        end

        ## The <tt>SERVER_PROTOCOL</tt> must match the regexp <tt>HTTP/\d(\.\d)?</tt>.
        server_protocol = env['SERVER_PROTOCOL']
        unless %r{HTTP/\d(\.\d)?}.match?(server_protocol)
          raise LintError, "env[SERVER_PROTOCOL] does not match HTTP/\\d(\\.\\d)?"
        end

        ## The environment must not contain the keys
        ## <tt>HTTP_CONTENT_TYPE</tt> or <tt>HTTP_CONTENT_LENGTH</tt>
        ## (use the versions without <tt>HTTP_</tt>).
        %w[HTTP_CONTENT_TYPE HTTP_CONTENT_LENGTH].each { |header|
          if env.include? header
            raise LintError, "env contains #{header}, must use #{header[5..-1]}"
          end
        }

        ## The CGI keys (named without a period) must have String values.
        ## If the string values for CGI keys contain non-ASCII characters,
        ## they should use ASCII-8BIT encoding.
        env.each { |key, value|
          next  if key.include? "."   # Skip extensions
          unless value.kind_of? String
            raise LintError, "env variable #{key} has non-string value #{value.inspect}"
          end
          next if value.encoding == Encoding::ASCII_8BIT
          unless value.b !~ /[\x80-\xff]/n
            raise LintError, "env variable #{key} has value containing non-ASCII characters and has non-ASCII-8BIT encoding #{value.inspect} encoding: #{value.encoding}"
          end
        }

        ## There are the following restrictions:

        ## * <tt>rack.url_scheme</tt> must either be +http+ or +https+.
        unless %w[http https].include?(env[RACK_URL_SCHEME])
          raise LintError, "rack.url_scheme unknown: #{env[RACK_URL_SCHEME].inspect}"
        end

        ## * There may be a valid input stream in <tt>rack.input</tt>.
        if rack_input = env[RACK_INPUT]
          check_input_stream(rack_input)
          @env[RACK_INPUT] = InputWrapper.new(rack_input)
        end

        ## * There must be a valid error stream in <tt>rack.errors</tt>.
        rack_errors = env[RACK_ERRORS]
        check_error_stream(rack_errors)
        @env[RACK_ERRORS] = ErrorWrapper.new(rack_errors)

        ## * There may be a valid hijack callback in <tt>rack.hijack</tt>
        check_hijack env
        ## * There may be a valid early hints callback in <tt>rack.early_hints</tt>
        check_early_hints env

        ## * The <tt>REQUEST_METHOD</tt> must be a valid token.
        unless env[REQUEST_METHOD] =~ /\A[0-9A-Za-z!\#$%&'*+.^_`|~-]+\z/
          raise LintError, "REQUEST_METHOD unknown: #{env[REQUEST_METHOD].dump}"
        end

        ## * The <tt>SCRIPT_NAME</tt>, if non-empty, must start with <tt>/</tt>
        if env.include?(SCRIPT_NAME) && env[SCRIPT_NAME] != "" && env[SCRIPT_NAME] !~ /\A\//
          raise LintError, "SCRIPT_NAME must start with /"
        end

        ## * The <tt>PATH_INFO</tt>, if provided, must be a valid request target or an empty string.
        if env.include?(PATH_INFO)
          case env[PATH_INFO]
          when REQUEST_PATH_ASTERISK_FORM
            ##   * Only <tt>OPTIONS</tt> requests may have <tt>PATH_INFO</tt> set to <tt>*</tt> (asterisk-form).
            unless env[REQUEST_METHOD] == OPTIONS
              raise LintError, "Only OPTIONS requests may have PATH_INFO set to '*' (asterisk-form)"
            end
          when REQUEST_PATH_AUTHORITY_FORM
            ##   * Only <tt>CONNECT</tt> requests may have <tt>PATH_INFO</tt> set to an authority (authority-form). Note that in HTTP/2+, the authority-form is not a valid request target.
            unless env[REQUEST_METHOD] == CONNECT
              raise LintError, "Only CONNECT requests may have PATH_INFO set to an authority (authority-form)"
            end
          when REQUEST_PATH_ABSOLUTE_FORM
            ##   * <tt>CONNECT</tt> and <tt>OPTIONS</tt> requests must not have <tt>PATH_INFO</tt> set to a URI (absolute-form).
            if env[REQUEST_METHOD] == CONNECT || env[REQUEST_METHOD] == OPTIONS
              raise LintError, "CONNECT and OPTIONS requests must not have PATH_INFO set to a URI (absolute-form)"
            end
          when REQUEST_PATH_ORIGIN_FORM
            ##   * Otherwise, <tt>PATH_INFO</tt> must start with a <tt>/</tt> and must not include a fragment part starting with '#' (origin-form).
          when ""
            # Empty string is okay.
          else
            raise LintError, "PATH_INFO must start with a '/' and must not include a fragment part starting with '#' (origin-form)"
          end
        end

        ## * The <tt>CONTENT_LENGTH</tt>, if given, must consist of digits only.
        if env.include?("CONTENT_LENGTH") && env["CONTENT_LENGTH"] !~ /\A\d+\z/
          raise LintError, "Invalid CONTENT_LENGTH: #{env["CONTENT_LENGTH"]}"
        end

        ## * One of <tt>SCRIPT_NAME</tt> or <tt>PATH_INFO</tt> must be
        ##   set. <tt>PATH_INFO</tt> should be <tt>/</tt> if
        ##   <tt>SCRIPT_NAME</tt> is empty.
        unless env[SCRIPT_NAME] || env[PATH_INFO]
          raise LintError, "One of SCRIPT_NAME or PATH_INFO must be set (make PATH_INFO '/' if SCRIPT_NAME is empty)"
        end
        ##   <tt>SCRIPT_NAME</tt> never should be <tt>/</tt>, but instead be empty.
        unless env[SCRIPT_NAME] != "/"
          raise LintError, "SCRIPT_NAME cannot be '/', make it '' and PATH_INFO '/'"
        end

        ## <tt>rack.response_finished</tt>:: An array of callables run by the server after the response has been
        ## processed. This would typically be invoked after sending the response to the client, but it could also be
        ## invoked if an error occurs while generating the response or sending the response; in that case, the error
        ## argument will be a subclass of +Exception+.
        ## The callables are invoked with +env, status, headers, error+ arguments and should not raise any
        ## exceptions. They should be invoked in reverse order of registration.
        if callables = env[RACK_RESPONSE_FINISHED]
          raise LintError, "rack.response_finished must be an array of callable objects" unless callables.is_a?(Array)

          callables.each do |callable|
            raise LintError, "rack.response_finished values must respond to call(env, status, headers, error)" unless callable.respond_to?(:call)
          end
        end
      end

      ##
      ## === The Input Stream
      ##
      ## The input stream is an IO-like object which contains the raw HTTP
      ## POST data.
      def check_input_stream(input)
        ## When applicable, its external encoding must be "ASCII-8BIT" and it
        ## must be opened in binary mode.
        if input.respond_to?(:external_encoding) && input.external_encoding != Encoding::ASCII_8BIT
          raise LintError, "rack.input #{input} does not have ASCII-8BIT as its external encoding"
        end
        if input.respond_to?(:binmode?) && !input.binmode?
          raise LintError, "rack.input #{input} is not opened in binary mode"
        end

        ## The input stream must respond to +gets+, +each+, and +read+.
        [:gets, :each, :read].each { |method|
          unless input.respond_to? method
            raise LintError, "rack.input #{input} does not respond to ##{method}"
          end
        }
      end

      class InputWrapper
        def initialize(input)
          @input = input
        end

        ## * +gets+ must be called without arguments and return a string,
        ##   or +nil+ on EOF.
        def gets(*args)
          raise LintError, "rack.input#gets called with arguments" unless args.size == 0
          v = @input.gets
          unless v.nil? or v.kind_of? String
            raise LintError, "rack.input#gets didn't return a String"
          end
          v
        end

        ## * +read+ behaves like <tt>IO#read</tt>.
        ##   Its signature is <tt>read([length, [buffer]])</tt>.
        ##
        ##   If given, +length+ must be a non-negative Integer (>= 0) or +nil+,
        ##   and +buffer+ must be a String and may not be nil.
        ##
        ##   If +length+ is given and not nil, then this method reads at most
        ##   +length+ bytes from the input stream.
        ##
        ##   If +length+ is not given or nil, then this method reads
        ##   all data until EOF.
        ##
        ##   When EOF is reached, this method returns nil if +length+ is given
        ##   and not nil, or "" if +length+ is not given or is nil.
        ##
        ##   If +buffer+ is given, then the read data will be placed
        ##   into +buffer+ instead of a newly created String object.
        def read(*args)
          unless args.size <= 2
            raise LintError, "rack.input#read called with too many arguments"
          end
          if args.size >= 1
            unless args.first.kind_of?(Integer) || args.first.nil?
              raise LintError, "rack.input#read called with non-integer and non-nil length"
            end
            unless args.first.nil? || args.first >= 0
              raise LintError, "rack.input#read called with a negative length"
            end
          end
          if args.size >= 2
            unless args[1].kind_of?(String)
              raise LintError, "rack.input#read called with non-String buffer"
            end
          end

          v = @input.read(*args)

          unless v.nil? or v.kind_of? String
            raise LintError, "rack.input#read didn't return nil or a String"
          end
          if args[0].nil?
            unless !v.nil?
              raise LintError, "rack.input#read(nil) returned nil on EOF"
            end
          end

          v
        end

        ## * +each+ must be called without arguments and only yield Strings.
        def each(*args)
          raise LintError, "rack.input#each called with arguments" unless args.size == 0
          @input.each { |line|
            unless line.kind_of? String
              raise LintError, "rack.input#each didn't yield a String"
            end
            yield line
          }
        end

        ## * +close+ can be called on the input stream to indicate that
        ##   any remaining input is not needed.
        def close(*args)
          @input.close(*args)
        end
      end

      ##
      ## === The Error Stream
      ##
      def check_error_stream(error)
        ## The error stream must respond to +puts+, +write+ and +flush+.
        [:puts, :write, :flush].each { |method|
          unless error.respond_to? method
            raise LintError, "rack.error #{error} does not respond to ##{method}"
          end
        }
      end

      class ErrorWrapper
        def initialize(error)
          @error = error
        end

        ## * +puts+ must be called with a single argument that responds to +to_s+.
        def puts(str)
          @error.puts str
        end

        ## * +write+ must be called with a single argument that is a String.
        def write(str)
          raise LintError, "rack.errors#write not called with a String" unless str.kind_of? String
          @error.write str
        end

        ## * +flush+ must be called without arguments and must be called
        ##   in order to make the error appear for sure.
        def flush
          @error.flush
        end

        ## * +close+ must never be called on the error stream.
        def close(*args)
          raise LintError, "rack.errors#close must not be called"
        end
      end

      ##
      ## === Hijacking
      ##
      ## The hijacking interfaces provides a means for an application to take
      ## control of the HTTP connection. There are two distinct hijack
      ## interfaces: full hijacking where the application takes over the raw
      ## connection, and partial hijacking where the application takes over
      ## just the response body stream. In both cases, the application is
      ## responsible for closing the hijacked stream.
      ##
      ## Full hijacking only works with HTTP/1. Partial hijacking is functionally
      ## equivalent to streaming bodies, and is still optionally supported for
      ## backwards compatibility with older Rack versions.
      ##
      ## ==== Full Hijack
      ##
      ## Full hijack is used to completely take over an HTTP/1 connection. It
      ## occurs before any headers are written and causes the request to
      ## ignores any response generated by the application.
      ##
      ## It is intended to be used when applications need access to raw HTTP/1
      ## connection.
      ##
      def check_hijack(env)
        ## If +rack.hijack+ is present in +env+, it must respond to +call+
        if original_hijack = env[RACK_HIJACK]
          raise LintError, "rack.hijack must respond to call" unless original_hijack.respond_to?(:call)

          env[RACK_HIJACK] = proc do
            io = original_hijack.call

            ## and return an +IO+ instance which can be used to read and write
            ## to the underlying connection using HTTP/1 semantics and
            ## formatting.
            raise LintError, "rack.hijack must return an IO instance" unless io.is_a?(IO)

            io
          end
        end
      end

      ##
      ## ==== Partial Hijack
      ##
      ## Partial hijack is used for bi-directional streaming of the request and
      ## response body. It occurs after the status and headers are written by
      ## the server and causes the server to ignore the Body of the response.
      ##
      ## It is intended to be used when applications need bi-directional
      ## streaming.
      ##
      def check_hijack_response(headers, env)
        ## If +rack.hijack?+ is present in +env+ and truthy,
        if env[RACK_IS_HIJACK]
          ## an application may set the special response header +rack.hijack+
          if original_hijack = headers[RACK_HIJACK]
            ## to an object that responds to +call+,
            unless original_hijack.respond_to?(:call)
              raise LintError, 'rack.hijack header must respond to #call'
            end
            ## accepting a +stream+ argument.
            return proc do |io|
              original_hijack.call StreamWrapper.new(io)
            end
          end
          ##
          ## After the response status and headers have been sent, this hijack
          ## callback will be invoked with a +stream+ argument which follows the
          ## same interface as outlined in "Streaming Body". Servers must
          ## ignore the +body+ part of the response tuple when the
          ## +rack.hijack+ response header is present. Using an empty +Array+
          ## instance is recommended.
        else
          ##
          ## The special response header +rack.hijack+ must only be set
          ## if the request +env+ has a truthy +rack.hijack?+.
          if headers.key?(RACK_HIJACK)
            raise LintError, 'rack.hijack header must not be present if server does not support hijacking'
          end
        end

        nil
      end

      ##
      ## === Early Hints
      ##
      ## The application or any middleware may call the <tt>rack.early_hints</tt>
      ## with an object which would be valid as the headers of a Rack response.
      def check_early_hints(env)
        if env[RACK_EARLY_HINTS]
          ##
          ## If <tt>rack.early_hints</tt> is present, it must respond to #call.
          unless env[RACK_EARLY_HINTS].respond_to?(:call)
            raise LintError, "rack.early_hints must respond to call"
          end

          original_callback = env[RACK_EARLY_HINTS]
          env[RACK_EARLY_HINTS] = lambda do |headers|
            ## If <tt>rack.early_hints</tt> is called, it must be called with
            ## valid Rack response headers.
            check_headers(headers)
            original_callback.call(headers)
          end
        end
      end

      ##
      ## == The Response
      ##
      ## === The Status
      ##
      def check_status(status)
        ## This is an HTTP status. It must be an Integer greater than or equal to
        ## 100.
        unless status.is_a?(Integer) && status >= 100
          raise LintError, "Status must be an Integer >=100"
        end
      end

      ##
      ## === The Headers
      ##
      def check_headers(headers)
        ## The headers must be a unfrozen Hash.
        unless headers.kind_of?(Hash)
          raise LintError, "headers object should be a hash, but isn't (got #{headers.class} as headers)"
        end

        if headers.frozen?
          raise LintError, "headers object should not be frozen, but is"
        end

        headers.each do |key, value|
          ## The header keys must be Strings.
          unless key.kind_of? String
            raise LintError, "header key must be a string, was #{key.class}"
          end

          ## Special headers starting "rack." are for communicating with the
          ## server, and must not be sent back to the client.
          next if key.start_with?("rack.")

          ## The header must not contain a +Status+ key.
          raise LintError, "header must not contain status" if key == "status"
          ## Header keys must conform to RFC7230 token specification, i.e. cannot
          ## contain non-printable ASCII, DQUOTE or "(),/:;<=>?@[\]{}".
          raise LintError, "invalid header name: #{key}" if key =~ /[\(\),\/:;<=>\?@\[\\\]{}[:cntrl:]]/
          ## Header keys must not contain uppercase ASCII characters (A-Z).
          raise LintError, "uppercase character in header name: #{key}" if key =~ /[A-Z]/

          ## Header values must be either a String instance,
          if value.kind_of?(String)
            check_header_value(key, value)
          elsif value.kind_of?(Array)
            ## or an Array of String instances,
            value.each{|value| check_header_value(key, value)}
          else
            raise LintError, "a header value must be a String or Array of Strings, but the value of '#{key}' is a #{value.class}"
          end
        end
      end

      def check_header_value(key, value)
        ## such that each String instance must not contain characters below 037.
        if value =~ /[\000-\037]/
          raise LintError, "invalid header value #{key}: #{value.inspect}"
        end
      end

      ##
      ## ==== The +content-type+ Header
      ##
      def check_content_type_header(status, headers)
        headers.each { |key, value|
          ## There must not be a <tt>content-type</tt> header key when the +Status+ is 1xx,
          ## 204, or 304.
          if key == "content-type"
            if Rack::Utils::STATUS_WITH_NO_ENTITY_BODY.key? status.to_i
              raise LintError, "content-type header found in #{status} response, not allowed"
            end
            return
          end
        }
      end

      ##
      ## ==== The +content-length+ Header
      ##
      def check_content_length_header(status, headers)
        headers.each { |key, value|
          if key == 'content-length'
            ## There must not be a <tt>content-length</tt> header key when the
            ## +Status+ is 1xx, 204, or 304.
            if Rack::Utils::STATUS_WITH_NO_ENTITY_BODY.key? status.to_i
              raise LintError, "content-length header found in #{status} response, not allowed"
            end
            @content_length = value
          end
        }
      end

      def verify_content_length(size)
        if @head_request
          unless size == 0
            raise LintError, "Response body was given for HEAD request, but should be empty"
          end
        elsif @content_length
          unless @content_length == size.to_s
            raise LintError, "content-length header was #{@content_length}, but should be #{size}"
          end
        end
      end

      ## 
      ## ==== The +rack.protocol+ Header
      ##
      def check_rack_protocol_header(status, headers)
        ## If the +rack.protocol+ header is present, it must be a +String+, and
        ## must be one of the values from the +rack.protocol+ array from the
        ## environment.
        protocol = headers['rack.protocol']

        if protocol
          request_protocols = @env['rack.protocol']

          if request_protocols.nil?
            raise LintError, "rack.protocol header is #{protocol.inspect}, but rack.protocol was not set in request!"
          elsif !request_protocols.include?(protocol)
            raise LintError, "rack.protocol header is #{protocol.inspect}, but should be one of #{request_protocols.inspect} from the request!"
          end
        end
      end
      ##
      ## Setting this value informs the server that it should perform a
      ## connection upgrade. In HTTP/1, this is done using the +upgrade+
      ## header. In HTTP/2, this is done by accepting the request.
      ##
      ## === The Body
      ##
      ## The Body is typically an +Array+ of +String+ instances, an enumerable
      ## that yields +String+ instances, a +Proc+ instance, or a File-like
      ## object.
      ##
      ## The Body must respond to +each+ or +call+. It may optionally respond
      ## to +to_path+ or +to_ary+. A Body that responds to +each+ is considered
      ## to be an Enumerable Body. A Body that responds to +call+ is considered
      ## to be a Streaming Body.
      ##
      ## A Body that responds to both +each+ and +call+ must be treated as an
      ## Enumerable Body, not a Streaming Body. If it responds to +each+, you
      ## must call +each+ and not +call+. If the Body doesn't respond to
      ## +each+, then you can assume it responds to +call+.
      ##
      ## The Body must either be consumed or returned. The Body is consumed by
      ## optionally calling either +each+ or +call+.
      ## Then, if the Body responds to +close+, it must be called to release
      ## any resources associated with the generation of the body.
      ## In other words, +close+ must always be called at least once; typically
      ## after the web server has sent the response to the client, but also in
      ## cases where the Rack application makes internal/virtual requests and
      ## discards the response.
      ##
      def close
        ##
        ## After calling +close+, the Body is considered closed and should not
        ## be consumed again.
        @closed = true

        ## If the original Body is replaced by a new Body, the new Body must
        ## also consume the original Body by calling +close+ if possible.
        @body.close if @body.respond_to?(:close)

        index = @lint.index(self)
        unless @env['rack.lint'][0..index].all? {|lint| lint.instance_variable_get(:@closed)}
          raise LintError, "Body has not been closed"
        end
      end

      def verify_to_path
        ##
        ## If the Body responds to +to_path+, it must return a +String+
        ## path for the local file system whose contents are identical
        ## to that produced by calling +each+; this may be used by the
        ## server as an alternative, possibly more efficient way to
        ## transport the response. The +to_path+ method does not consume
        ## the body.
        if @body.respond_to?(:to_path)
          unless ::File.exist? @body.to_path
            raise LintError, "The file identified by body.to_path does not exist"
          end
        end
      end

      ##
      ## ==== Enumerable Body
      ##
      def each
        ## The Enumerable Body must respond to +each+.
        raise LintError, "Enumerable Body must respond to each" unless @body.respond_to?(:each)

        ## It must only be called once.
        raise LintError, "Response body must only be invoked once (#{@invoked})" unless @invoked.nil?

        ## It must not be called after being closed,
        raise LintError, "Response body is already closed" if @closed

        @invoked = :each

        @body.each do |chunk|
          ## and must only yield String values.
          unless chunk.kind_of? String
            raise LintError, "Body yielded non-string value #{chunk.inspect}"
          end

          ##
          ## Middleware must not call +each+ directly on the Body.
          ## Instead, middleware can return a new Body that calls +each+ on the
          ## original Body, yielding at least once per iteration.
          if @lint[0] == self
            @env['rack.lint.body_iteration'] += 1
          else
            if (@env['rack.lint.body_iteration'] -= 1) > 0
              raise LintError, "New body must yield at least once per iteration of old body"
            end
          end

          @size += chunk.bytesize
          yield chunk
        end

        verify_content_length(@size)

        verify_to_path
      end

      BODY_METHODS = {to_ary: true, each: true, call: true, to_path: true}

      def to_path
        @body.to_path
      end

      def respond_to?(name, *)
        if BODY_METHODS.key?(name)
          @body.respond_to?(name)
        else
          super
        end
      end

      ##
      ## If the Body responds to +to_ary+, it must return an +Array+ whose
      ## contents are identical to that produced by calling +each+.
      ## Middleware may call +to_ary+ directly on the Body and return a new
      ## Body in its place. In other words, middleware can only process the
      ## Body directly if it responds to +to_ary+. If the Body responds to both
      ## +to_ary+ and +close+, its implementation of +to_ary+ must call
      ## +close+.
      def to_ary
        @body.to_ary.tap do |content|
          unless content == @body.enum_for.to_a
            raise LintError, "#to_ary not identical to contents produced by calling #each"
          end
        end
      ensure
        close
      end

      ##
      ## ==== Streaming Body
      ##
      def call(stream)
        ## The Streaming Body must respond to +call+.
        raise LintError, "Streaming Body must respond to call" unless @body.respond_to?(:call)

        ## It must only be called once.
        raise LintError, "Response body must only be invoked once (#{@invoked})" unless @invoked.nil?

        ## It must not be called after being closed.
        raise LintError, "Response body is already closed" if @closed

        @invoked = :call

        ## It takes a +stream+ argument.
        ##
        ## The +stream+ argument must implement:
        ## <tt>read, write, <<, flush, close, close_read, close_write, closed?</tt>
        ##
        @body.call(StreamWrapper.new(stream))
      end

      class StreamWrapper
        extend Forwardable

        ## The semantics of these IO methods must be a best effort match to
        ## those of a normal Ruby IO or Socket object, using standard arguments
        ## and raising standard exceptions. Servers are encouraged to simply
        ## pass on real IO objects, although it is recognized that this approach
        ## is not directly compatible with HTTP/2.
        REQUIRED_METHODS = [
          :read, :write, :<<, :flush, :close,
          :close_read, :close_write, :closed?
        ]

        def_delegators :@stream, *REQUIRED_METHODS

        def initialize(stream)
          @stream = stream

          REQUIRED_METHODS.each do |method_name|
            raise LintError, "Stream must respond to #{method_name}" unless stream.respond_to?(method_name)
          end
        end
      end

      # :startdoc:
    end
  end
end

##
## == Thanks
## Some parts of this specification are adopted from {PEP 333 – Python Web Server Gateway Interface v1.0}[https://peps.python.org/pep-0333/]
## I'd like to thank everyone involved in that effort.
