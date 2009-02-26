module Rack
  # *Handlers* connect web servers with Rack.
  #
  # Rack includes Handlers for Mongrel, WEBrick, FastCGI, CGI, SCGI
  # and LiteSpeed.
  #
  # Handlers usually are activated by calling <tt>MyHandler.run(myapp)</tt>.
  # A second optional hash can be passed to include server-specific
  # configuration.
  module Handler
    def self.get(server)
      return unless server

      if klass = @handlers[server]
        obj = Object
        klass.split("::").each { |x| obj = obj.const_get(x) }
        obj
      else
        # try to require the matching rack handler file (presumably from another gem)
        # the next couple of parts attempt to manipulate a proper constant name into
        # a proper filename. BlahBlahBlorp -> either blah_blah_blorp or blahblahblorp.
        begin
          # first try blahblahblorp from BlahBlahBlorp (this is the cheaper case, so do it first)
          require 'rack/handler/' + server.downcase
        rescue LoadError
          begin
            # next try and find blah_blorp_bloop from BlahBlorpBloop
            require 'rack/handler/' + server.gsub(/^[A-Z]/) {|a| a.downcase }.gsub(/[A-Z]/) {|a| "_#{a.downcase}" }
          rescue LoadError
            begin
              require 'rack/handler/' + server.gsub(/_/, '')
            rescue LoadError
              # ignore it, move on and fail later.
            end
          end
        end
        # Now try to const_get the handler in question after properly capitalizing it.
        # blah_blah_blorp -> BlahBlahBlorp
        return Rack::Handler.const_get(server.gsub(/(^|_)([a-z])/) {|a| $2.upcase })
      end
    end

    def self.register(server, klass)
      @handlers ||= {}
      @handlers[server] = klass
    end

    autoload :CGI, "rack/handler/cgi"
    autoload :FastCGI, "rack/handler/fastcgi"
    autoload :Mongrel, "rack/handler/mongrel"
    autoload :EventedMongrel, "rack/handler/evented_mongrel"
    autoload :SwiftipliedMongrel, "rack/handler/swiftiplied_mongrel"
    autoload :WEBrick, "rack/handler/webrick"
    autoload :LSWS, "rack/handler/lsws"
    autoload :SCGI, "rack/handler/scgi"
    autoload :Thin, "rack/handler/thin"

    register 'cgi', 'Rack::Handler::CGI'
    register 'fastcgi', 'Rack::Handler::FastCGI'
    register 'mongrel', 'Rack::Handler::Mongrel'
    register 'emongrel', 'Rack::Handler::EventedMongrel'
    register 'smongrel', 'Rack::Handler::SwiftipliedMongrel'
    register 'webrick', 'Rack::Handler::WEBrick'
    register 'lsws', 'Rack::Handler::LSWS'
    register 'scgi', 'Rack::Handler::SCGI'
    register 'thin', 'Rack::Handler::Thin'
  end
end
