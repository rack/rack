require 'optparse'

module Rack

  class Options
    def parse!(args)
      options = {}
      opt_parser = OptionParser.new("", 24, '  ') do |opts|
        opts.banner = "Usage: rackup [ruby options] [rack options] [rackup config]"

        opts.separator ""
        opts.separator "Ruby options:"

        lineno = 1
        opts.on("-e", "--eval LINE", "evaluate a LINE of code") { |line|
          eval line, TOPLEVEL_BINDING, "-e", lineno
          lineno += 1
        }

        opts.on("-b", "--builder BUILDER_LINE", "evaluate a BUILDER_LINE of code as a builder script") { |line|
          options[:builder] = line
        }

        opts.on("-d", "--debug", "set debugging flags (set $DEBUG to true)") {
          options[:debug] = true
        }
        opts.on("-w", "--warn", "turn warnings on for your script") {
          options[:warn] = true
        }
        opts.on("-q", "--quiet", "turn off logging") {
          options[:quiet] = true
        }

        opts.on("-I", "--include PATH",
                "specify $LOAD_PATH (may be used more than once)") { |path|
          (options[:include] ||= []).concat(path.split(":"))
        }

        opts.on("-r", "--require LIBRARY",
                "require the library, before executing your script") { |library|
          options[:require] = library
        }

        opts.separator ""
        opts.separator "Rack options:"
        opts.on("-s", "--server SERVER", "serve using SERVER (thin/puma/webrick/mongrel)") { |s|
          options[:server] = s
        }

        opts.on("-o", "--host HOST", "listen on HOST (default: 0.0.0.0)") { |host|
          options[:Host] = host
        }

        opts.on("-p", "--port PORT", "use PORT (default: 9292)") { |port|
          options[:Port] = port
        }

        opts.on("-O", "--option NAME[=VALUE]", "pass VALUE to the server as option NAME. If no VALUE, sets it to true. Run '#{$0} -s SERVER -h' to get a list of options for SERVER") { |name|
          name, value = name.split('=', 2)
          value = true if value.nil?
          options[name.to_sym] = value
        }

        opts.on("-E", "--env ENVIRONMENT", "use ENVIRONMENT for defaults (default: development)") { |e|
          options[:environment] = e
        }

        opts.on("-D", "--daemonize", "run daemonized in the background") { |d|
          options[:daemonize] = d ? true : false
        }

        opts.on("-P", "--pid FILE", "file to store PID") { |f|
          options[:pid] = ::File.expand_path(f)
        }

        opts.separator ""
        opts.separator "Common options:"

        opts.on_tail("-h", "-?", "--help", "Show this message") do
          puts opts
          puts handler_opts(options)

          exit
        end

        opts.on_tail("--version", "Show version") do
          puts "Rack #{Rack.version} (Release: #{Rack.release})"
          exit
        end
      end

      begin
        opt_parser.parse! args
      rescue OptionParser::InvalidOption => e
        warn e.message
        abort opt_parser.to_s
      end

      options[:config] = args.last if args.last
      options
    end

    def handler_opts(options)
      begin
        info = []
        server = Rack::Handler.get(options[:server]) || Rack::Handler.default(options)
        if server && server.respond_to?(:valid_options)
          info << ""
          info << "Server-specific options for #{server.name}:"

          has_options = false
          server.valid_options.each do |name, description|
            next if name.to_s.match(/^(Host|Port)[^a-zA-Z]/) # ignore handler's host and port options, we do our own.
            info << "  -O %-21s %s" % [name, description]
            has_options = true
          end
          return "" if !has_options
        end
        info.join("\n")
      rescue NameError, LoadError
        return "Warning: Could not find handler specified (#{options[:server] || 'default'}) to determine handler-specific options"
      end
    end
  end

end
