# Rack 3 Upgrade Guide

This document is a work in progress, but outlines some of the key changes in
Rack 3 which you should be aware of in order to update your server, middleware
and/or applications.

## Interface Changes

### Rack 2 & Rack 3 compatibility

Most applications can be compatible with Rack 2 and 3 by following the strict intersection of the Rack Specifications, notably:

- Response array must now be non-frozen.
- Response `status` must now be an integer greater than or equal to 100.
- Response `headers` must now be an unfrozen hash.
- Response header keys can no longer include uppercase characters.
- `rack.input` is no longer required to be rewindable.
- `rack.multithread`/`rack.multiprocess`/`rack.run_once`/`rack.version` are no longer required environment keys.
- `rack.hijack?` (partial hijack) and `rack.hijack` (full hijack) are now independently optional.
- `rack.hijack_io` has been removed completely.
- `SERVER_PROTOCOL` is now a required key, matching the HTTP protocol used in the request.
- Middleware must no longer call `#each` on the body, but they can call `#to_ary` on the body if it responds to `#to_ary`.

There is one changed feature in Rack 3 which is not backwards compatible:

- Response header values can be an `Array` to handle multiple values (and no longer supports `\n` encoded headers).

You can achieve compatibility by using `Rack::Response#add_header` which provides an interface for adding headers without concern for the underlying format.

There is one new feature in Rack 3 which is not directly backwards compatible:

- Response body can now respond to `#call` (streaming body) instead of `#each` (enumerable body), for the equivalent of response hijacking in previous versions.

If supported by your server, you can use partial rack hijack instead (or wrap this behaviour in a middleware).

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

### `Rack::Session` was moved to a separate gem.

Previously, `Rack::Session` was part of the `rack` gem. Not every application
needs it, and it increases the security surface area of the `rack`, so it was
decided to extract it into its own gem `rack-session` which can be updated
independently.

Applications that make use of `rack-session` will need to add that gem as a
dependency:

```ruby
gem 'rack-session'
```

This provides all the previously available functionality.

### `bin/rackup`, `Rack::Server`, `Rack::Handler`and  `Rack::Lobster` were moved to a separate gem.

Previously, the `rackup` executable was included with Rack. Because WEBrick is
no longer a default gem with Ruby, we had to make a decision: either `rack`
should depend on `webrick` or we should move that functionality into a
separate gem. We chose the latter which will hopefully allow us to innovate
more rapidly on the design and implementation of `rackup` separately from
"rack the interface".

In Rack 3, you will need to include:

```ruby
gem 'rackup'
```

This provides all the previously available functionality.

The classes `Rack::Server`, `Rack::Handler` and  `Rack::Lobster` have been moved to the rackup gem too and renamed to `Rackup::Server`, `Rackup::Handler` and  `Rackup::Lobster` respectively.

To start an app with `Rackup::Server` with Rack 3 :

```ruby
require 'rackup'
Rackup::Server.start app: app, Port: 3000
```

#### `config.ru` autoloading is disabled unless `require 'rack'`

Previously, rack modules like `rack/directory` were autoloaded because `rackup` did require 'rack'. In Rack 3, you will need to write `require 'rack'` or require specific module explicitly.

```diff
+require 'rack'
run Rack::Directory.new '.'
```

or

```diff
+require 'rack/directory'
run Rack::Directory.new '.'
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
value of `rack.hijack?`. Now, it only applies to partial hijack (which now can
be replaced by streaming bodies).

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

Previously, `rack.input` was required to be rewindable, i.e. `io.seek(0)` but
this was only generally possible with a file based backing, which prevented
efficient streaming of request bodies. Now, `rack.input` is not required to be
rewindable.

### `rack.input` is no longer rewound after consuming form and multipart data

Previously `.rewind` was called after consuming form and multipart data. Use
`Rack::RewindableInput::Middleware` to make the body rewindable, and call
`.rewind` explicitly to match this behavior.

### Invalid nested query parsing syntax

Previously, Rack 2 was able to parse the query string `a[b[c]]=x` in the same
way as `a[b][c]=x`. This invalid syntax was never officially supported. However,
some libraries and applications used it anyway. Due to implementation details,
Rack 2 ended up parsing it the same as the correct syntax. The implementation
was changed in Rack 3, and this invalid syntax is no longer parsed the same way
as the correct syntax:

```ruby
Rack::Utils.parse_nested_query("a[b[c]]=x")
# Rack 3 => {"a"=>{"b[c"=>{"]"=>"x"}}} ❌
# Rack 2 => {"a"=>{"b"=>{"c"=>"x"}}} ✅
```

The correct syntax for nested parameters is `a[b][c]=x` and you'll need
to change that in your application code to be compatible with Rack 3:

```ruby
Rack::Utils.parse_nested_query("a[b][c]=x")
# Rack 3 => {"a"=>{"b"=>{"c"=>"x"}}} ✅
# Rack 2 => {"a"=>{"b"=>{"c"=>"x"}}} ✅
```

See <https://github.com/rack/rack/issues/2128> for more context.

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
  return [200, [['content-type', 'text/plain']], ["Hello World"]]
end
```

Now you must use a hash instance:

```ruby
def call(env)
  return [200, {'content-type' => 'text/plain'}, ["Hello World"]]
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

If you want your code to work with Rack 3 without having to manually lowercase
each header key used, instead of using a plain hash for headers, you can use
`Rack::Headers` on Rack 3.

```ruby
  headers = defined?(Rack::Headers) ? Rack::Headers.new : {}
```

`Rack::Headers` is a subclass of Hash that will automatically lowercase keys:

```ruby
  headers = Rack::Headers.new
  headers['Foo'] = 'bar'
  headers['FOO'] # => 'bar'
  headers.keys   # => ['foo']
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

### Status needs to be an `Integer`

The response status is now required to be an `Integer` with a value greater or equal to 100.

Previously any object that responded to `#to_i` was allowed, so a response like `["200", {}, ""]` will need to be replaced with `[200, {}, ""]` and so on. This can be done by calling `#to_i` on the status object yourself.
