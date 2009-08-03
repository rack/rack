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

      @env[Const::ENV_PATH_INFO] =       @url.path
      @env[Const::ENV_QUERY_STRING] =    @url.query  if @url.query
      @env[Const::ENV_HTTP_HOST] =       @url.host   if @url.host
      @env[Const::ENV_HTTP_PORT] =       @url.port   if @url.port
      @env[Const::RACK_URL_SCHEME] = @url.scheme if @url.scheme

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
      @script_name = env[Const::ENV_SCRIPT_NAME]
      @app.call(env.merge('rack.recursive.include' => method(:include)))
    rescue ForwardRequest => req
      call(env.merge(req.env))
    end

    def include(env, path)
      unless path.index(@script_name) == 0 && (path[@script_name.size] == ?/ ||
                                               path[@script_name.size].nil?)
        raise ArgumentError, "can only include below #{@script_name}, not #{path}"
      end

      env = env.merge(Const::ENV_PATH_INFO => path, Const::ENV_SCRIPT_NAME => @script_name,
                      Const::ENV_REQUEST_METHOD => Const::GET,
                      Const::ENV_CONTENT_LENGTH => "0", Const::ENV_CONTENT_TYPE => "",
                      Const::RACK_INPUT => StringIO.new(""))
      @app.call(env)
    end
  end
end
