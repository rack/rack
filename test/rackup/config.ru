require "#{File.dirname(__FILE__)}/../testrequest"

$stderr = StringIO.new

class EnvMiddleware
  def initialize(app)
    @app = app
  end
  
  def call(env)
    if env["PATH_INFO"] == "/broken_lint"
      return [200, {}, ["Broken Lint"]]
    end

    env["test.$DEBUG"]      = $DEBUG
    env["test.$EVAL"]       = BUKKIT if defined?(BUKKIT)
    env["test.$VERBOSE"]    = $VERBOSE
    env["test.$LOAD_PATH"]  = $LOAD_PATH
    env["test.Ping"]        = defined?(Ping)
    @app.call(env)
  end
end

use EnvMiddleware
run TestRequest.new
