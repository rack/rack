module Rack
  class NullLogger
    def info(progname = nil, &block);  end
    def debug(progname = nil, &block); end
    def warn(progname = nil, &block);  end
    def error(progname = nil, &block); end
    def fatal(progname = nil, &block); end
  end
end
