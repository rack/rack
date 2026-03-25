# Getting Started With Rack

This guide demonstrates how to create a basic Rack application and run it using a Rack-compliant web server. We'll use [Puma](https://puma.io) as the web server in this tutorial. Alternatives can be found in the [Readme](./index.html#supported-web-servers).

## Creating a Rack Application

A Rack app is a class which implements a `call` method. It is passed an [`env`](./SPEC_rdoc.html#the-request-environment) hash, known as the Rack environment, which is created by parsing the incoming HTTP request.

```ruby
class App
  def call(env)
    [200, { "content-type" => "text/plain" }, ["Hello World"]]
  end
end

run App.new
```

When an HTTP request is made, the Rack-compliant web server parses it to create the `env` hash, and forwards it to the application's `call` method. This method must return an array representing the HTTP response.

The first element is the HTTP response code, in this case `200`. The second element is a hash containing any Rack and HTTP response headers we wish to send. And the last element is an array of strings representing the response body.

You can run this app by organizing it into a folder:

```bash
$ mkdir rack-demo
$ cd rack-demo
$ bundle init
$ bundle add rack puma
$ cat > config.ru << APP
class App
  def call(env)
    [200, { "content-type" => "text/plain" }, ["Hello World"]]
  end
end

run App.new
APP
```

`config.ru` is the conventional entrypoint for Rack applications. Start Puma to run the app:

```bash
$ bundle exec puma
```

Your app should be available at <http://localhost:9292>. 

```bash
$ curl localhost:9292
Hello World
```

You can use a different entrypoint if you wish — as long as the file extension is `.ru`.

```bash
$ bundle exec puma server.ru
```

The syntax to manually specify the entrypoint might differ for other servers — consult the documentation.

### Handling Routes and HTTP Verbs

Routing to different paths can be handled by querying the `env` Hash:

```ruby
class App
  def call(env)
    path = env["PATH_INFO"]
    case path
    when "/admin"
      [200, { "content-type" => "text/plain" }, ["Hello Admin!"]]
    else
      [200, { "content-type" => "text/plain" }, ["Hello World"]]
    end
  end
end

run App.new
```

The HTTP verb is also available within the `env`:

```ruby
class App
  def call(env)
    request_method = env["REQUEST_METHOD"]
    case request_method
    when "POST"
      [200, { "content-type" => "text/plain" }, ["Responding to a POST"]]
    when "GET"
      [200, { "content-type" => "text/plain" }, ["Responding to a GET"]]      
    else
      [200, { "content-type" => "text/plain" }, ["Responding to all other verbs"]]
    end
  end
end

run App.new
```

Rack provides a [`Rack::Request`](./Rack/Request.html) utility class which implements a convenient interface to the Rack environment. It is stateless, meaning the `env` passed to the constructor will be directly accessed and modified.

The above examples can be rewritten as:

```ruby
class App
  def call(env)
    request = Rack::Request.new(env)
    case request.path_info
    when "/admin"
      [200, { "content-type" => "text/plain" }, ["Hello Admin!"]]
    else
      [200, { "content-type" => "text/plain" }, ["Hello World"]]
    end
  end
end

run App.new
```

```ruby
class App
  def call(env)
    request = Rack::Request.new(env)
    case request.request_method
    when "POST"
      [200, { "content-type" => "text/plain" }, ["Responding to a POST"]]
    when "GET"
      [200, { "content-type" => "text/plain" }, ["Responding to a GET"]]      
    else
      [200, { "content-type" => "text/plain" }, ["Responding to all other verbs"]]
    end
  end
end

run App.new
```

### Reading Request Bodies

HTTP requests using verbs other than `GET` or `HEAD` may contain a body. Rack provides access to this via `env["rack.input"]` or `Rack::Request#body`. An `IO`-like [input stream](SPEC_rdoc.html#the-input-stream) object will be returned.

The below application demonstrates how a `POST` request with a JSON body could be handled:

```ruby
require "json"

class App
  def call(env)
    request = Rack::Request.new(env)
    case request.request_method
    when "POST"
      request_body = request.body.read
      parsed_body = JSON.parse(request_body)
      [200, { "content-type" => "text/plain" }, ["Hello #{parsed_body['city']}"]]
    else
      [200, { "content-type" => "text/plain" }, ["Hello World!"]]
    end
  end
end

run App.new
```

Run the application and make a request:

```bash
$ curl -X "POST" "http://localhost:9292/" \
     	-H 'Content-Type: application/json; charset=utf-8' \
     	-d '{ "city": "London" }'
Hello London     	
```

### Streaming Response Bodies

To stream a response back to the client rather than sending a buffered response, a `Proc` can be returned in place of the response body. The `Proc` is yielded a `stream` to write to.

```ruby
class App
  def call(env)
    response_stream = proc do |stream|
      5.times do
        stream.write "#{Time.now}\n\n"
        sleep 1
      end
    ensure
      stream.close
    end

    [200, { "content-type" => "text/plain" }, response_stream]
  end
end

run App.new
```

Run this application and then make a request to it:

```bash
$ curl localhost:9292
```

You'll see the time is printed out 5 times at 1 second intervals and then the connection is closed. 

Streaming responses allow Rack applications to implement communication over persistent connections such as [HTTP Server Sent Events](https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events/Using_server-sent_events) and [WebSockets](https://developer.mozilla.org/en-US/docs/Web/API/WebSockets_API).

## Rack Middleware

Rack applications are built up of a stack of _middleware_ which may operate upon a request before it reaches the main application, and again after the application has processed the request. Middleware is usually used for tasks like logging, caching, authentication, and measuring performance.

A Rack middleware needs to be `initialize`d with the Rack `app` which is passed down through the middleware stack to the main application, and must implement a `call` method which operates on the request:

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

Middleware can short-circuit the stack by skipping `@app.call` completely and returning a reponse by itself. This means the request never hits the main application. A middleware to authenticate a request might use this technique.

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

class App
  def call(env)
    [200, { "content-type" => "text/plain" }, ["Hello World"]]
  end
end

use AuthenticateRequest
run App.new
```

This DSL to construct Rack applications is provided by `Rack::Builder`. Consult the [RDoc](./Rack/Builder.html) for advanced usage.

Rack [ships with](index.html#available-middleware-shipped-with-rack) several pieces of middleware for common use-cases.

## Conclusion

Since Rack provides a standardized interface between web servers and applications, all Rack-compliant web applications allow access to the underlying Rack objects such as the environment and the response. Refer to your chosen framework's documentation for the exact syntax. 

