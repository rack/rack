# frozen_string_literal: true

module Rack
  # *Handlers* connect web servers with Rack.
  #
  # Rack includes Handlers for Thin, WEBrick, FastCGI, CGI, SCGI
  # and LiteSpeed.
  #
  # Handlers usually are activated by calling <tt>MyHandler.run(myapp)</tt>.
  # A second optional hash can be passed to include server-specific
  # configuration.
  module Handler
    def self.get(server)
      return unless server
      server = server.to_s

      unless @handlers.include? server
        load_error = try_require('rack/handler', server)
      end

      if klass = @handlers[server]
        const_get(klass)
      else
        const_get(server, false)
      end

    rescue NameError => name_error
      raise load_error || name_error
    end

    # Select first available Rack handler given an `Array` of server names.
    # Raises `LoadError` if no handler was found.
    #
    #   > pick ['puma', 'webrick']
    #   => Rack::Handler::WEBrick
    def self.pick(server_names)
      server_names = Array(server_names)
      server_names.each do |server_name|
        begin
          return get(server_name.to_s)
        rescue LoadError, NameError
        end
      end

      raise LoadError, "Couldn't find handler for: #{server_names.join(', ')}."
    end

    RACK_HANDLER = 'RACK_HANDLER'

    SERVER_NAMES = %w(puma falcon webrick).freeze
    private_constant :SERVER_NAMES

    def self.default
      if rack_handler = ENV[RACK_HANDLER]
        self.get(rack_handler)
      else
        pick SERVER_NAMES
      end
    end

    # Transforms server-name constants to their canonical form as filenames,
    # then tries to require them but silences the LoadError if not found
    #
    # Naming convention:
    #
    #   Foo # => 'foo'
    #   FooBar # => 'foo_bar.rb'
    #   FooBAR # => 'foobar.rb'
    #   FOObar # => 'foobar.rb'
    #   FOOBAR # => 'foobar.rb'
    #   FooBarBaz # => 'foo_bar_baz.rb'
    def self.try_require(prefix, const_name)
      file = const_name.gsub(/^[A-Z]+/) { |pre| pre.downcase }.
        gsub(/[A-Z]+[^A-Z]/, '_\&').downcase

      require(::File.join(prefix, file))
      nil
    rescue LoadError => error
      error
    end

    def self.register(server, klass)
      @handlers ||= {}
      @handlers[server.to_s] = klass.to_s
    end

    autoload :WEBrick, "rack/handler/webrick"
    register 'webrick', 'Rack::Handler::WEBrick'
  end
end
