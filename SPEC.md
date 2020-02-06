# Rack Specification

This specification aims to formalize the Rack protocol. You can (and should) use `Rack::Lint` to enforce it. When you develop middleware, be sure to add a linter before and after to catch all mistakes in your test harness.

## Rack applications

A Rack application is a Ruby object (not a class) that responds to `call`. It takes exactly one argument, the **environment** and returns an `Array` of exactly three values: The **status**, the **headers**, and the **body**.

### The Environment

The environment must be an unfrozen instance of Hash that includes CGI-like headers. The application is free to modify the environment. The environment is required to include these variables except when they'd be empty, unless otherwise specified.

#### `REQUEST_METHOD`

The HTTP request method, such as "GET" or "POST". This cannot ever be an empty string, and so is always required.

#### `SCRIPT_NAME`

The initial portion of the request URL's "path" that corresponds to the application object, so that the application knows its virtual "location". This may be an empty string, if the application corresponds to the "root" of the server.

#### `PATH_INFO`

The remainder of the request URL's "path", designating the virtual "location" of the request's target within the application. This may be an empty string, if the request URL targets the application root and does not have a trailing slash. This value may be percent-encoded when originating from a URL.

#### `QUERY_STRING`

The portion of the request URL that follows the `?`, if any. May be empty, but is always required!

#### `SERVER_NAME`, `SERVER_PORT`

When combined with `SCRIPT_NAME` and `PATH_INFO`, these variables can be used to complete the URL. Note, however, that `HTTP_HOST`, if present, should be used in preference to `SERVER_NAME` for reconstructing the request URL. `SERVER_NAME` and `SERVER_PORT` can never be empty strings, and so are always required.

#### `HTTP_` Variables

Variables corresponding to the client-supplied HTTP request headers (i.e., variables whose names begin with `HTTP_`). The presence or absence of these variables should correspond with the presence or absence of the appropriate HTTP header in the request. See [RFC3875 section 4.1.18](https://tools.ietf.org/html/rfc3875#section-4.1.18) for specific behavior.

#### `rack.version`

The Array representing this version of Rack See Rack::VERSION, that corresponds to the version of this SPEC.

#### `rack.url_scheme`

Set to `http` or `https`, depending on the request URL.

#### `rack.input`

See below, the input stream.

#### `rack.errors`

See below, the error stream.

#### `rack.multithread`

Set to `true` if the application object may be simultaneously invoked by another thread in the same process, `false` otherwise.

#### `rack.multiprocess`

Set to `true` if an equivalent application object may be simultaneously invoked by another process, `false` otherwise.

#### `rack.run_once`

Set to `true` if the server expects (but does not guarantee!) that the application will only be invoked this one time during the life of its containing process. Normally, this will only be true for a server based on CGI (or something similar).

#### `rack.hijack?`

present and true if the server supports connection hijacking. See below, hijacking.

#### `rack.hijack`

An object responding to `#call` that must be called at least once before using `rack.hijack_io`. `#call` **must** return `rack.hijack_io` as well as setting it in `env`.

#### `rack.hijack_io`

If `rack.hijack?` is true, and `rack.hijack` has received `#call`, this will contain an object resembling an `IO`. See hijacking.

#### `rack.session` (optional)

A hash like interface for storing request session data. The store must implement:

```
  store(key, value) # aliased as []=
  fetch(key, default = nil) # aliased as []
  delete(key)
  clear
  to_hash # returning unfrozen Hash instance
```

#### `rack.logger`  (optional)

A common object interface for logging messages. The object must implement:

```
  info(message, &block)
  debug(message, &block)
  warn(message, &block)
  error(message, &block)
  fatal(message, &block)
```

The block is invoked only if the logging level is enabled and returns a string which is printed.

#### `rack.multipart.buffer_size` (optional)

An Integer hint to the multipart parser as to what chunk size to use for reads and writes.

#### `rack.multipart.tempfile_factory` (optional)

An object responding to `#call` with two arguments, the `filename` and `content_type` given for the multipart form field, and returning an `IO`-like object that responds to `#<<` and optionally `#rewind`. This factory will be used to instantiate the tempfile for each multipart form file upload field, rather than the default class of `Tempfile`.

#### Server Specific Variables

The server or the application can store their own data in the environment, too. The keys must contain at least one dot, and should be prefixed uniquely. The prefix `rack.` is reserved for use with the Rack core distribution and other accepted specifications and must not be used otherwise. The environment must not contain the keys `HTTP_CONTENT_TYPE` or `HTTP_CONTENT_LENGTH` (use the versions without `HTTP_`). The CGI keys (named without a period) must have `String` values. If the string values for CGI keys contain non-ASCII characters, they should use ASCII-8BIT encoding. There are the following restrictions:

- `rack.version` must be an array of Integers.
- `rack.url_scheme` must either be `http` or `https`.
- There must be a valid input stream in `rack.input`.
- There must be a valid error stream in `rack.errors`.
- There may be a valid hijack stream in `rack.hijack_io`.
- The `REQUEST_METHOD` must be a valid token.
- The `SCRIPT_NAME`, if non-empty, must start with `/`.
- The `PATH_INFO`, if non-empty, must start with `/`.
- The `CONTENT_LENGTH`, if given, must consist of digits only.
- One of `SCRIPT_NAME` or `PATH_INFO` must be set. `PATH_INFO` should be `/` if `SCRIPT_NAME` is empty. `SCRIPT_NAME` never should be `/`, but instead be empty.

### The Input Stream

The input stream is an IO-like object which contains the raw HTTP POST data. When applicable, its external encoding must be "ASCII-8BIT" and it must be opened in binary mode, for Ruby 1.9 compatibility. The input stream must respond to `gets`, `each`, `read` and `rewind`.

- `gets` must be called without arguments and return a string, or `nil` on EOF.
- `read` behaves like `IO#read`. Its signature is `read([length], [buffer])`. If given, `length` must be a non-negative `Integer` (>= 0) or `nil`, and `buffer` must be a `String` and may not be `nil`. If `length` is given and not `nil`, then this method reads at most `length` bytes from the input stream. If `length` is not given or `nil`, then this method reads all data until EOF. When EOF is reached, this method returns `nil` if `length` is given and not `nil`, or "" if `length` is not given or is `nil`. If `buffer` is given, then the read data will be placed into `buffer` instead of a newly created `String` object.
- `each` must be called without arguments and only yield `String` instances.
- `rewind` must be called without arguments. It rewinds the input stream back to the beginning. It must not raise `Errno::ESPIPE`: that is, it may not be a pipe or a socket. Therefore, handler developers must buffer the input data into some rewindable object if the underlying input stream is not rewindable.
- `close` must never be called on the input stream.

### The Error Stream

The error stream must respond to `puts`, `write` and `flush`.

- `puts` must be called with a single argument that responds to `to_s`.
- `write` must be called with a single argument that is a `String`.
- `flush` must be called without arguments and must be called in order to make the error appear for sure.
- `close` must never be called on the error stream.

### Hijacking

#### Request (before status)

If `rack.hijack?` is `true` then `rack.hijack` must respond to `#call`. `rack.hijack` must return the `io` that will also be assigned (or is already present, in `rack.hijack_io`. `rack.hijack_io` must respond to: 

```
  read
  write
  read_nonblock
  write_nonblock
  flush
  close
  close_read
  close_write
  closed?
```

The semantics of these methods must be a best effort match to those of a normal Ruby `IO` or `Socket` object, using standard arguments and raising standard exceptions. Servers are encouraged to simply pass on real `IO` objects, although it is recognized that this approach is not directly compatible with HTTP 2.0. `IO` provided in `rack.hijack_io` should preference the `IO::WaitReadable` and `IO::WaitWritable` APIs wherever supported.

There is a deliberate lack of full specification around `rack.hijack_io`, as semantics will change from server to server. Users are encouraged to utilize this API with a knowledge of their server choice, and servers may extend the functionality of `hijack_io` to provide additional features to users. The purpose of `rack.hijack` is for Rack to "get out of the way", as such, Rack only provides the minimum of specification and support.

If `rack.hijack?` is `false`, then `rack.hijack` nor should not be set. If `rack.hijack?` is false, then `rack.hijack_io` should not be set.

#### Response (after headers)

It is also possible to hijack a response after the status and headers have been sent. In order to do this, an application may set the special header `rack.hijack` to an object that responds to `call` accepting an argument that conforms to the `rack.hijack_io` protocol. After the headers have been sent, and this hijack callback has been called, the application is now responsible for the remaining lifecycle of the IO. The application is also responsible for maintaining HTTP semantics. Of specific note, in almost all cases in the current SPEC, applications will have wanted to specify the header `Connection: close` in HTTP/1.1, and not `Connection: keep-alive`, as there is no protocol for returning hijacked sockets to the web server. For that purpose, use the body streaming API instead (progressively yielding strings via each). Servers must ignore the `body` part of the response tuple when the `rack.hijack` response API is in use. The special response header `rack.hijack` must only be set if the request `env` has `rack.hijack?` `true`.

#### Conventions

- Middleware should not use hijack unless it is handling the whole response.
- Middleware may wrap the IO object for the response pattern.
- Middleware should not wrap the IO object for the request pattern. The request pattern is intended to provide the hijacker with "raw tcp".

## The Response

### The Status

This is an HTTP status. When parsed as integer using `#to_i`, it must be greater than or equal to 100.

### The Headers

The header must respond to `each`, and yield values of key and value. The header keys must be Strings. Special headers starting `rack.` are for communicating with the server, and must not be sent back to the client. The header must not contain a `Status` key. The header must conform to [RFC7230] token specification, i.e. cannot contain non-printable `ASCII`, `DQUOTE` or `(),/:;<=>?@[]{}`. The values of the header must be Strings, consisting of lines (for multiple header values, e.g. multiple `Set-Cookie` values) separated by newlines `\n`. The lines must not contain characters below 037.

[RFC7230]: https://tools.ietf.org/html/rfc7230

### The Content-Type

There must not be a `Content-Type`, when the `Status` is 1xx, 204 or 304.

### The Content-Length

There must not be a `Content-Length` header when the `Status` is 1xx, 204 or 304.

### The Body

The Body must respond to `each` and must only yield String values. The Body itself should not be an instance of String, as this will break in Ruby 1.9. If the Body responds to `close`, it will be called after iteration. If the body is replaced by a middleware after action, the original body must be closed first, if it responds to close. If the Body responds to `to_path`, it must return a String identifying the location of a file whose contents are identical to that produced by calling `each`; this may be used by the server as an alternative, possibly more efficient way to transport the response. The Body commonly is an Array of Strings, the application instance itself, or a File-like object.

## Thanks

Some parts of this specification are adopted from PEP333: Python Web Server Gateway Interface v1.0 (http://www.python.org/dev/peps/pep-0333/). I'd like to thank everyone involved in that effort.
