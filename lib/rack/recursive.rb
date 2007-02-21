require 'uri'

module Rack
  class ForwardRequest < Exception
    attr_reader :url, :env

    def initialize(url, env={})
      @url = URI(url)
      @env = env

      @env["PATH_INFO"] =       @url.path
      @env["QUERY_STRING"] =    @url.query  if @url.query
      @env["HTTP_HOST"] =       @url.host   if @url.host
      @env["HTTP_PORT"] =       @url.port   if @url.port
      @env["rack.url_scheme"] = @url.scheme if @url.scheme

      super "forwarding to #{url}"
    end
  end

  class Recursive
    def initialize(app)
      @app = app
    end

    def call(env)
      @script_name = env["SCRIPT_NAME"]
      @app.call(env.merge('rack.recursive.include' => method(:include)))
    rescue ForwardRequest => req
      call(env.merge(req.env))
    end

    def include(env, path)
      unless path.index(@script_name) == 0 && (path[@script_name.size] == ?/ ||
                                               path[@script_name.size].nil?)
        raise ArgumentError, "can only include below #{@script_name}, not #{path}"
      end

      env = env.merge("PATH_INFO" => path, "SCRIPT_NAME" => @script_name,
                      "REQUEST_METHOD" => "GET",
                      "CONTENT_LENGTH" => "0", "CONTENT_TYPE" => "",
                      "rack.input" => StringIO.new(""))
      @app.call(env)
    end
  end
end
