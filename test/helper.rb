require 'minitest/autorun'

module Rack
  class TestCase
    # Keep this first.
    PID = fork {
      ENV['RACK_ENV'] = 'deployment'
      ENV['RUBYLIB'] = [
        ::File.expand_path('../../lib', __FILE__),
        ENV['RUBYLIB'],
      ].compact.join(':')

      Dir.chdir(::File.expand_path("../cgi", __FILE__)) do
        exec "lighttpd -D -f lighttpd.conf"
      end
    }

    Minitest.after_run do
      Process.kill 15, PID
      Process.wait(PID)
    end
  end
end
