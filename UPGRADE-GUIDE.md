# Rack 3 Upgrade Guide

This document is a work in progress, but outlines some of the key changes in
Rack 3 which you should be aware of in order to update your server, middleware
and/or applications.

## Interface Changes

### `config.ru` `Rack::Builder#run` now accepts block

Previously, `Rack::Builder#run` method would only accept a callable argument:

```ruby
run lambda{|env| [200, {}, ["Hello World"]]}
```

This can be rewritten more simply:

```ruby
run do |env|
  [200, {}, ["Hello World"]]
end
```

### Response bodies can be used for bi-directional streaming

Previously, the `rack.hijack` response header could be used for implementing
bi-directional streaming (e.g. WebSockets).

```ruby
def call(env)
  stream_callback = proc do |stream|
    stream.read(...)
    stream.write(...)
  ensure
    stream.close(...)
  end

  return [200, {'rack.hijack' => stream_callback}, []]
end
```

This feature was optional and tricky to use correctly. You can now achieve the
same thing by giving `stream_callback` as the response body:

```ruby
def call(env)
  stream_callback = proc do |stream|
    stream.read(...)
    stream.write(...)
  ensure
    stream.close(...)
  end

  return [200, {}, stream_callback]
end
```

### `Rack::Session` is now moved to an external gem

Previously, `Rack::Session` was part of the `rack` gem. Not every application
needs it, and it increases the security surface area of the `rack`, so it was
decided to extract it into its own gem `rack-session` which can be updated
independently.

Applications that make use of `rack-session` will need to add that gem as a
dependency:

```ruby
gem 'rack-session'
```



## Request Changes

### `rack.version` is no longer required

Previously, the "rack protocol version" was available in `rack.version` but it
was not practically useful, so it has been removed as a requirement.

### `rack.multithread`/`rack.multiprocess`/`rack.run_once` are no longer required

Previously, servers tried to provide these keys to reflect the execution
environment. These come too late to be useful, so they have been removed as  a
requirement.

### `rack.hijack?` now only applies to partial hijack

Previously, both full and partial hijiack were controlled by the presence and
value of `rack.hijack?`. Now, it only applies to partial hijack (which itself
has been effectively replaced by streaming bodies).

### `rack.hijack` alone indicates that you can execute a full hijack

Previously, `rack.hijack?` had to be truthy, as well as having `rack.hijack`
present in the request environment. Now, the presence of the `rack.hijack`
callback is enough.

### `rack.hijack_io` is removed

Previously, the server would try to set `rack.hijack_io` into the request
environment when `rack.hijack` was invoked for a full hijack. This was often
impossible if a middleware had called `env.dup`, so this requirement has been
dropped entirely.

### `rack.input` is no longer required to be rewindable

Previosuly, `rack.input` was required to be rewindable, i.e. `io.seek(0)` but
this was only generally possible with a file based backing, which prevented
efficient streaming of request bodies. Now, `rack.input` is not required to be
rewindable.

## Response Changes

### Response must be mutable

Rack 3 requires the response Array `[status, headers, body]` to be mutable.
Existing code that uses a frozen response will need to be changed:

```ruby
NOT_FOUND = [404, {}, ["Not Found"]].freeze

def call(env)
  ...
  return NOT_FOUND
end
```

should be rewritten as:

```ruby
def not_found
  [404, {}, ["Not Found"]]
end

def call(env)
  ...
  return not_found
end
```

Note there is a subtle bug in the former version: the headers hash is mutable
and can be modified, and these modifications can leak into subsequent requests.

### Response headers must be a mutable hash

Rack 3 requires response headers to be a mutable hash. Previously it could be
any object that would respond to `#each` and yield `key`/`value` pairs.
Previously, the following was acceptable:

```ruby
def call(env)
  return [200, [['content-type', 'text/plain']], ["Hello World]]
end
```

Now you must use a hash instance:

```ruby
def call(env)
  return [200, {'content-type' => 'text/plain'}, ["Hello World]]
end
```

This ensures middleware can predictably update headers as needed.

### Response Headers must be lower case

Rack 3 requires all response headers to be lower case. This is to simplify
fetching and updating response headers. Previously you had to use something like
`Rack::HeadersHash`

```ruby
def call(env)
  response = @app.call(env)
  # HeaderHash must allocate internal objects and compute lower case keys:
  headers = Rack::Utils::HeaderHash[response[1]]

  cache_response(headers['ETag'], response)

  ...
end
```

but now you must just use the normal form for HTTP header:

```ruby
def call(env)
  response = @app.call(env)
  # A plain hash with lower case keys:
  headers = response[1]

  cache_response(headers['etag'], response)

  ...
end
```

### Multiple response header values are encoded using an `Array`

Response header values can be an Array to handle multiple values (and no longer
supports `\n` encoded headers). If you use `Rack::Response`, you don't need to
do anything, but if manually append values to response headers, you will need to
promote them to an Array, e.g.

```ruby
def set_cookie_header!(headers, key, value)
  if header = headers[SET_COOKIE]
    if header.is_a?(Array)
      header << set_cookie_header(key, value)
    else
      headers[SET_COOKIE] = [header, set_cookie_header(key, value)]
    end
  else
    headers[SET_COOKIE] = set_cookie_header(key, value)
  end
end
```

### Response body might not respond to `#each`

Rack 3 has more strict requirements on response bodies. Previously, response
body would only need to respond to `#each` and optionally `#close`. In addition,
there was no way to determine whether it was safe to call `#each` and buffer the
response.

### Response bodies can be buffered if they expose `#to_ary`

If your body responds to `#to_ary` then it must return an `Array` whose contents
are identical to that produced by calling `#each`. If the body responds to both
`#to_ary` and `#close` then its implementation of `#to_ary` must also call
`#close`.

Previously, it was not possible to determine whether a response body was
immediately available (could be buffered) or was streaming chunks. This case is
now unambiguously exposed by `#to_ary`:

```ruby
def call(env)
  status, headers, body = @app.call(env)

  # Check if we can buffer the body into an Array, so we can compute a digest:
  if body.respond_to?(:to_ary)
    body = body.to_ary
    digest = digest_body(body)
    headers[ETAG_STRING] = %(W/"#{digest}") if digest
  end

  return [status, headers, body]  
end
```

### Middleware should not directly modify the response body 

Be aware that the response body might not respond to `#each` and you must now
check if the body responds to `#each` or not to determine if it is an enumerable
or streaming body.

You must not call `#each` directly on the body and instead you should return a
new body that calls `#each` on the original body.
