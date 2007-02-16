require 'zlib'

# Paste has a Pony, Rack has a Lobster!

module Rack
  LobsterString = Zlib::Inflate.inflate("eJx9kEEOwyAMBO99xd7MAcytUhPlJyj2
  P6jy9i4k9EQyGAnBarEXeCBqSkntNXsi/ZCvC48zGQoZKikGrFMZvgS5ZHd+aGWVuWwhVF0
  t1drVmiR42HcWNz5w3QanT+2gIvTVCiE1lm1Y0eU4JGmIIbaKwextKn8rvW+p5PIwFl8ZWJ
  I8jyiTlhTcYXkekJAzTyYN6E08A+dk8voBkAVTJQ==".delete("\n ").unpack("m*")[0])

  Lobster = lambda { |env|
    if env["QUERY_STRING"].include?("flip")
      lobster = LobsterString.split("\n").
        map { |line| line.ljust(42).reverse }.
        join("\n")
      href = "?"
    else
      lobster = LobsterString
      href = "?flip"
    end
    
    [200, {"Content-Type" => "text/html"},
     ["<title>Lobstericious!</title>",
      "<pre>", lobster, "</pre>",
      "<a href='#{href}'>flip!</a>"]
    ]
  }
end

if $0 == __FILE__
  require 'rack'
  Rack::Handler::WEBrick.run Rack::Lint.new(Rack::Lobster), :Port => 9202
end
