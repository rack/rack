# Getting Started With Rack

This guide demonstrates how to create a basic Rack application and run it using a Rack-compliant web server. We'll use [Puma](https://puma.io) in this tutorial — alternative web servers can be found in the [Readme](https://github.com/rack/rack?tab=readme-ov-file#supported-web-servers).

## Creating a Rack Application

A Rack app is an object which implements a `call` method. It is passed an [`env`](https://github.com/rack/rack/blob/main/SPEC.rdoc#the-request-environment) hash, known as the Rack environment.

```ruby
rack_app = lambda do |env|
  [200, { "content-type" => "text/plain" }, ["Hello World"]]
end

run rack_app
```

A class can also be used to define a Rack app:

```ruby
class App
  def self.call(env)
    new(env).route
  end

  def initialize(env)
    @env = env
  end

  def route
    [200, { "content-type" => "text/plain" }, ["Hello World"]]
  end
end

run App
```

When an HTTP request is made, the Rack-compliant web server parses it to create the `env` hash, and calls the application with `env`. The `call` method must return an array with exactly three elements, representing the HTTP response:

1. The HTTP response code (`200` in the above example).
2. A hash containing any HTTP response headers we wish to send.
3. An enumerable object that yields strings, representing the response body.

Rack applications are generally run using the web server's command line program, with the entry point for the application being stored in a `config.ru` file:

```bash
$ cat > config.ru << APP
rack_app = lambda do |env|
  [200, { "content-type" => "text/plain" }, ["Hello World"]]
end
run rack_app
APP
$ gem install puma
$ puma
```

Your app should be available at <http://localhost:9292>. 

```bash
$ curl localhost:9292
Hello World
```

### Handling Routes and HTTP Verbs

Routing to different paths can be handled by querying the `env` hash:

```ruby
app = lambda do |env|
  body = 
    case env["PATH_INFO"]
    when "/admin"
      ["Hello Admin"]
    else
      ["Hello World"]
    end

  [200, { "content-type" => "text/plain" }, body]
end

run app
```

The HTTP verb is also available within the `env`:

```ruby
app = lambda do |env|
  [200, { "content-type" => "text/plain" }, ["HTTP #{env["REQUEST_METHOD"]}"]]
end

run app
```

Rack provides `Rack::Request`, which implements a convenient interface to a Rack environment.

The above examples can be rewritten as:

```ruby
app = lambda do |env|
  request = Rack::Request.new(env)
  body = 
    case request.path_info
    when "/admin"
      ["Hello Admin"]
    else
      ["Hello World"]
    end

  [200, { "content-type" => "text/plain" }, body]
end

run app
```

```ruby
app = lambda do |env|
  request = Rack::Request.new(env)
  [200, { "content-type" => "text/plain" }, ["HTTP #{request.request_method}"]]
end

run app
```

### Reading Request Bodies

If a body is submitted with the HTTP request, Rack provides access to it as an `IO`-like [input stream](https://github.com/rack/rack/blob/main/SPEC.rdoc#the-input-stream) object, via `env["rack.input"]` or `Rack::Request#body`.

The below application demonstrates how a `POST` request with a JSON body could be handled:

```ruby
require "json"

app = lambda do |env|
  body = if env["REQUEST_METHOD"] == "POST"
  	raw_body = env["rack.input"].read
    city = JSON.parse(raw_body)['city']
    ["Hello #{city}"]
  else
    ["Hello World!"]
  end

  [200, { "content-type" => "text/plain" }, body]
end

run app
```

Run the application and make a request:

```bash
$ curl  -X "POST" "http://localhost:9292/" \
     	-H 'Content-Type: application/json; charset=utf-8' \
     	-d '{ "city": "London" }'
Hello London
```

### Streaming Response Bodies

In addition to the body being an enumerable of strings, the body can also be a callable object, which is yielded a `stream` to write to:

```ruby
app = lambda do |env|
  body = proc do |stream|
    5.times do
      stream.write "#{Time.now}\n\n"
      sleep 1
    end
  ensure
    stream.close
  end

  [200, { "content-type" => "text/plain" }, body]
end

run app
```

Run this application and then make a request to it:

```bash
$ curl localhost:9292
```

You'll see the time is printed out 5 times at 1 second intervals and then the connection is closed. 

Streaming bodies may make it easier for Rack applications to implement communication over persistent connections such as [HTTP Server Sent Events](https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events/Using_server-sent_events) and [WebSockets](https://developer.mozilla.org/en-US/docs/Web/API/WebSockets_API).

## Rack Middleware

Rack applications can be wrapped using _middleware_ which may operate upon a request before it reaches the main application, and again after the application has returned a response to the request. Middleware is usually used for tasks like logging, caching, authentication, and measuring performance.

A Rack middleware must have a `new` method that accepts the Rack app and any arguments used to configure the middleware. The `new` method must return a Rack application that responds to `call`. Typically, Rack middleware are classes, and each instance of the middleware wraps access to the related application:

```ruby
class MyMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    # Operations before the request hits the main application
    # -------------------------------------------------------

    # Propgate the request down the middleware stack
    status, headers, body = @app.call(env)

    # ---------------------------------------
    # Operations after the request comes back

    # Propogate the response up the middleware stack
    [status, headers, body]
  end
end
```

Middleware can short-circuit the stack by skipping `@app.call` completely and returning a reponse by itself. This means the request never hits the main application or the remaining middleware in the stack. A middleware to authenticate a request might use this technique.

```ruby
class AuthenticateRequest
  def initialize(app)
    @app = app
  end

  def call(env)
    if authenticated?(env["HTTP_AUTHORIZATION"])
      @app.call(env)
    else
      [401, { "content-type" => "text/plain" }, ["Authentication failed"]]
    end
  end

  def authenticated?(token)
    # ...
  end
end
```

Middleware is added to a Rack app with `use`:

```ruby
class AuthenticateRequest
  # ...
end

app = lambda do |env|
  [200, { "content-type" => "text/plain" }, ["Hello World"]]
end

use AuthenticateRequest
run app
```

This DSL to construct Rack applications is provided by `Rack::Builder`.

[Rack ships with several pieces of middleware for common use-cases](https://github.com/rack/rack?tab=readme-ov-file#available-middleware-shipped-with-rack).

## Conclusion

Since Rack provides a standardized interface between web servers and applications, in general, any Rack-compliant web application can run using any Rack-compliant web server. Rack uses a simple request (`env`) to response (`[status, headers, body]`) design, providing the foundation upon which the majority of Ruby web applications are built. 

As Rack is designed to be low-level, Ruby web applications are typically developed using frameworks that build on top of Rack. Most frameworks offer access to the low-level Rack API.