# ![Rack](contrib/logo.webp)

> **_NOTE:_** Rack v3.0.0 was recently released. Please check the [Upgrade
> Guide](UPGRADE-GUIDE.md) for more details about migrating your existing
> servers, middlewares and applications. For detailed information on specific
> changes, check the [Change Log](CHANGELOG.md).

Rack provides a minimal, modular, and adaptable interface for developing web
applications in Ruby. By wrapping HTTP requests and responses in the simplest
way possible, it unifies and distills the bridge between web servers, web
frameworks, and web application into a single method call.

The exact details of this are described in the [Rack Specification], which all
Rack applications should conform to.

## Installation

Add the rack gem to your application bundle, or follow the instructions provided
by a [supported web framework](#supported-web-frameworks):

```bash
# Install it generally:
$ gem install rack --pre

# or, add it to your current application gemfile:
$ bundle add rack --version 3.0.0
```

If you need features from `Rack::Session` or `bin/rackup` please add those gems separately.

```bash
$ gem install rack-session rackup
```

## Usage

Create a file called `config.ru` with the following contents:

```ruby
run do |env|
  [200, {}, ["Hello World"]]
end
```

Run this using the rackup gem or another [supported web
server](#supported-web-servers).

```bash
$ gem install rackup
$ rackup
$ curl http://localhost:9292
Hello World
```

## Supported web servers

Rack is supported by a wide range of servers, including:

* [Agoo](https://github.com/ohler55/agoo)
* [Falcon](https://github.com/socketry/falcon) **(Rack 3 Compatible)**
* [Iodine](https://github.com/boazsegev/iodine)
* [NGINX Unit](https://unit.nginx.org/)
* [Phusion Passenger](https://www.phusionpassenger.com/) (which is mod_rack for
  Apache and for nginx)
* [Puma](https://puma.io/)
* [Thin](https://github.com/macournoyer/thin)
* [Unicorn](https://yhbt.net/unicorn/)
* [uWSGI](https://uwsgi-docs.readthedocs.io/en/latest/)
* [Lamby](https://lamby.custominktech.com) (for AWS Lambda)

You will need to consult the server documentation to find out what features and
limitations they may have. In general, any valid Rack app will run the same on
all these servers, without changing anything.

### Rackup

Rack provides a separate gem, [rackup](https://github.com/rack/rackup) which is
a generic interface for running a Rack application on supported servers, which
include `WEBRick`, `Puma`, `Falcon` and others.

## Supported web frameworks

These frameworks and many others support the [Rack Specification]:

* [Camping](https://github.com/camping/camping)
* [Hanami](https://hanamirb.org/)
* [Padrino](https://padrinorb.com/)
* [Roda](https://github.com/jeremyevans/roda) **(Rack 3 Compatible)**
* [Ruby on Rails](https://rubyonrails.org/)
* [Sinatra](https://sinatrarb.com/)
* [Utopia](https://github.com/socketry/utopia) **(Rack 3 Compatible)**
* [WABuR](https://github.com/ohler55/wabur)

### Older (possibly unsupported) web frameworks

* [Ramaze](http://ramaze.net/)
* [Rum](https://github.com/leahneukirchen/rum)

## Available middleware shipped with Rack

Between the server and the framework, Rack can be customized to your
applications needs using middleware. Rack itself ships with the following
middleware:

* `Rack::CommonLogger` for creating Apache-style logfiles.
* `Rack::ConditionalGet` for returning [Not
  Modified](https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/304)
  responses when the response has not changed.
* `Rack::Config` for modifying the environment before processing the request.
* `Rack::ContentLength` for setting a `content-length` header based on body
  size.
* `Rack::ContentType` for setting a default `content-type` header for responses.
* `Rack::Deflater` for compressing responses with gzip.
* `Rack::ETag` for setting `etag` header on bodies that can be buffered.
* `Rack::Events` for providing easy hooks when a request is received and when
  the response is sent.
* `Rack::Files` for serving static files.
* `Rack::Head` for returning an empty body for HEAD requests.
* `Rack::Lint` for checking conformance to the [Rack Specification].
* `Rack::Lock` for serializing requests using a mutex.
* `Rack::Logger` for setting a logger to handle logging errors.
* `Rack::MethodOverride` for modifying the request method based on a submitted
  parameter.
* `Rack::Recursive` for including data from other paths in the application, and
  for performing internal redirects.
* `Rack::Reloader` for reloading files if they have been modified.
* `Rack::Runtime` for including a response header with the time taken to process
  the request.
* `Rack::Sendfile` for working with web servers that can use optimized file
  serving for file system paths.
* `Rack::ShowException` for catching unhandled exceptions and presenting them in
  a nice and helpful way with clickable backtrace.
* `Rack::ShowStatus` for using nice error pages for empty client error
  responses.
* `Rack::Static` for more configurable serving of static files.
* `Rack::TempfileReaper` for removing temporary files creating during a request.

All these components use the same interface, which is described in detail in the
[Rack Specification]. These optional components can be used in any way you wish.

### Convenience interfaces

If you want to develop outside of existing frameworks, implement your own ones,
or develop middleware, Rack provides many helpers to create Rack applications
quickly and without doing the same web stuff all over:

* `Rack::Request` which also provides query string parsing and multipart
  handling.
* `Rack::Response` for convenient generation of HTTP replies and cookie
  handling.
* `Rack::MockRequest` and `Rack::MockResponse` for efficient and quick testing
  of Rack application without real HTTP round-trips.
* `Rack::Cascade` for trying additional Rack applications if an application
  returns a not found or method not supported response.
* `Rack::Directory` for serving files under a given directory, with directory
  indexes.
* `Rack::MediaType` for parsing content-type headers.
* `Rack::Mime` for determining content-type based on file extension.
* `Rack::RewindableInput` for making any IO object rewindable, using a temporary
  file buffer.
* `Rack::URLMap` to route to multiple applications inside the same process.

## Configuration

Rack exposes several configuration parameters to control various features of the
implementation.

### `param_depth_limit`

```ruby
Rack::Utils.param_depth_limit = 32 # default
```

The maximum amount of nesting allowed in parameters. For example, if set to 3,
this query string would be allowed:

```
?a[b][c]=d
```

but this query string would not be allowed:

```
?a[b][c][d]=e
```

Limiting the depth prevents a possible stack overflow when parsing parameters.

### `multipart_file_limit`

```ruby
Rack::Utils.multipart_file_limit = 128 # default
```

The maximum number of parts with a filename a request can contain. Accepting
too many parts can lead to the server running out of file handles.

The default is 128, which means that a single request can't upload more than 128
files at once. Set to 0 for no limit.

Can also be set via the `RACK_MULTIPART_FILE_LIMIT` environment variable.

(This is also aliased as `multipart_part_limit` and `RACK_MULTIPART_PART_LIMIT` for compatibility)


### `multipart_total_part_limit`

The maximum total number of parts a request can contain of any type, including
both file and non-file form fields.

The default is 4096, which means that a single request can't contain more than
4096 parts.

Set to 0 for no limit.

Can also be set via the `RACK_MULTIPART_TOTAL_PART_LIMIT` environment variable.


## Changelog

See [CHANGELOG.md](CHANGELOG.md).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for specific details about how to make a
contribution to Rack.

Please post bugs, suggestions and patches to [GitHub
Issues](https://github.com/rack/rack/issues).

Please check our [Security Policy](https://github.com/rack/rack/security/policy)
for responsible disclosure and security bug reporting process. Due to wide usage
of the library, it is strongly preferred that we manage timing in order to
provide viable patches at the time of disclosure. Your assistance in this matter
is greatly appreciated.

## See Also

### `rack-contrib`

The plethora of useful middleware created the need for a project that collects
fresh Rack middleware. `rack-contrib` includes a variety of add-on components
for Rack and it is easy to contribute new modules.

* https://github.com/rack/rack-contrib

### `rack-session`

Provides convenient session management for Rack.

* https://github.com/rack/rack-session

## Thanks

The Rack Core Team, consisting of

* Aaron Patterson [tenderlove](https://github.com/tenderlove)
* Samuel Williams [ioquatix](https://github.com/ioquatix)
* Jeremy Evans [jeremyevans](https://github.com/jeremyevans)
* Eileen Uchitelle [eileencodes](https://github.com/eileencodes)
* Matthew Draper [matthewd](https://github.com/matthewd)
* Rafael França [rafaelfranca](https://github.com/rafaelfranca)

and the Rack Alumni

* Ryan Tomayko [rtomayko](https://github.com/rtomayko)
* Scytrin dai Kinthra [scytrin](https://github.com/scytrin)
* Leah Neukirchen [leahneukirchen](https://github.com/leahneukirchen)
* James Tucker [raggi](https://github.com/raggi)
* Josh Peek [josh](https://github.com/josh)
* José Valim [josevalim](https://github.com/josevalim)
* Michael Fellinger [manveru](https://github.com/manveru)
* Santiago Pastorino [spastorino](https://github.com/spastorino)
* Konstantin Haase [rkh](https://github.com/rkh)

would like to thank:

* Adrian Madrid, for the LiteSpeed handler.
* Christoffer Sawicki, for the first Rails adapter and `Rack::Deflater`.
* Tim Fletcher, for the HTTP authentication code.
* Luc Heinrich for the Cookie sessions, the static file handler and bugfixes.
* Armin Ronacher, for the logo and racktools.
* Alex Beregszaszi, Alexander Kahn, Anil Wadghule, Aredridel, Ben Alpert, Dan
  Kubb, Daniel Roethlisberger, Matt Todd, Tom Robinson, Phil Hagelberg, S. Brent
  Faulkner, Bosko Milekic, Daniel Rodríguez Troitiño, Genki Takiuchi, Geoffrey
  Grosenbach, Julien Sanchez, Kamal Fariz Mahyuddin, Masayoshi Takahashi,
  Patrick Aljordm, Mig, Kazuhiro Nishiyama, Jon Bardin, Konstantin Haase, Larry
  Siden, Matias Korhonen, Sam Ruby, Simon Chiang, Tim Connor, Timur Batyrshin,
  and Zach Brock for bug fixing and other improvements.
* Eric Wong, Hongli Lai, Jeremy Kemper for their continuous support and API
  improvements.
* Yehuda Katz and Carl Lerche for refactoring rackup.
* Brian Candler, for `Rack::ContentType`.
* Graham Batty, for improved handler loading.
* Stephen Bannasch, for bug reports and documentation.
* Gary Wright, for proposing a better `Rack::Response` interface.
* Jonathan Buch, for improvements regarding `Rack::Response`.
* Armin Röhrl, for tracking down bugs in the Cookie generator.
* Alexander Kellett for testing the Gem and reviewing the announcement.
* Marcus Rückert, for help with configuring and debugging lighttpd.
* The WSGI team for the well-done and documented work they've done and Rack
  builds up on.
* All bug reporters and patch contributors not mentioned above.

## License

Rack is released under the [MIT License](MIT-LICENSE).

[Rack Specification]: SPEC.rdoc
