require 'uri'

module Rack
  # Rack::ForwardRequest gets caught by Rack::Recursive and redirects
  # the current request to the app at +url+.
  #
  #   raise ForwardRequest.new("/not-found")
  #

  class ForwardRequest < Exception
    attr_reader :url, :env

    def initialize(url, env={})
      @url = URI(url)
      @env = env

      @env[CGI_VARIABLE::PATH_INFO] =       @url.path
      @env[CGI_VARIABLE::QUERY_STRING] =    @url.query  if @url.query
      @env[CGI_VARIABLE::HTTP_HOST] =       @url.host   if @url.host
      @env[CGI_VARIABLE::HTTP_PORT] =       @url.port   if @url.port
      @env[RACK_VARIABLE::URL_SCHEME] = @url.scheme if @url.scheme

      super "forwarding to #{url}"
    end
  end

  # Rack::Recursive allows applications called down the chain to
  # include data from other applications (by using
  # <tt>rack['rack.recursive.include'][...]</tt> or raise a
  # ForwardRequest to redirect internally.

  class Recursive
    def initialize(app)
      @app = app
    end

    def call(env)
      dup._call(env)
    end

    def _call(env)
      @script_name = env[CGI_VARIABLE::SCRIPT_NAME]
      @app.call(env.merge(RACK_VARIABLE::RECURSIVE_INCLUDE => method(:include)))
    rescue ForwardRequest => req
      call(env.merge(req.env))
    end

    def include(env, path)
      unless path.index(@script_name) == 0 && (path[@script_name.size] == ?/ ||
                                               path[@script_name.size].nil?)
        raise ArgumentError, "can only include below #{@script_name}, not #{path}"
      end

      env = env.merge(CGI_VARIABLE::PATH_INFO => path, CGI_VARIABLE::SCRIPT_NAME => @script_name,
                      CGI_VARIABLE::REQUEST_METHOD => HTTP_METHOD::GET,
                      CGI_VARIABLE::CONTENT_LENGTH => "0", CGI_VARIABLE::CONTENT_TYPE => "",
                      RACK_VARIABLE::INPUT => StringIO.new)
      @app.call(env)
    end
  end
end
