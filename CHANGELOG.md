# Changelog
All notable changes to this project will be documented in this file. For info on how to format all future additions to this file please reference [Keep A Changelog](https://keepachangelog.com/en/1.0.0/)

## [Unreleased]
### Added
- CHANGELOG.md using keep a changelog formatting by @twitnithegirl

### Changed
- `Rack::Utils.status_code` now raises an error when the status symbol is invalid instead of `500`.

### Removed
- HISTORY.md by @twitnithegirl
- NEWS.md by @twitnithegirl


#
#
# History/News Archive
Items below this line are from the previously maintained HISTORY.md and NEWS.md files. 
#

## [2.0.0]
- Rack::Session::Abstract::ID is deprecated. Please change to use Rack::Session::Abstract::Persisted

## [2.0.0.alpha] 2015-12-04
- First-party "SameSite" cookies. Browsers omit SameSite cookies from third-party requests, closing the door on many CSRF attacks.
- Pass `same_site: true` (or `:strict`) to enable: response.set_cookie 'foo', value: 'bar', same_site: true or `same_site: :lax` to use Lax enforcement: response.set_cookie 'foo', value: 'bar', same_site: :lax
- Based on version 7 of the Same-site Cookies internet draft:
	https://tools.ietf.org/html/draft-west-first-party-cookies-07
- Thanks to Ben Toews (@mastahyeti) and Bob Long (@bobjflong) for updating to drafts 5 and 7.
- Add `Rack::Events` middleware for adding event based middleware: middleware that does not care about the response body, but only cares about doing work at particular points in the request / response lifecycle.
- Add `Rack::Request#authority` to calculate the authority under which the response is being made (this will be handy for h2 pushes).
- Add `Rack::Response::Helpers#cache_control` and `cache_control=`. Use this for setting cache control headers on your response objects.
- Add `Rack::Response::Helpers#etag` and `etag=`.  Use this for setting etag values on the response.
- Introduce `Rack::Response::Helpers#add_header` to add a value to a multi-valued response header. Implemented in terms of other `Response#*_header` methods, so it's available to any response-like class that includes the `Helpers` module.
- Add `Rack::Request#add_header` to match.
- `Rack::Session::Abstract::ID` IS DEPRECATED.  Please switch to `Rack::Session::Abstract::Persisted`. `Rack::Session::Abstract::Persisted` uses a request object rather than the `env` hash.
- Pull `ENV` access inside the request object in to a module.  This will help with legacy Request objects that are ENV based but don't want to inherit from Rack::Request
- Move most methods on the `Rack::Request` to a module `Rack::Request::Helpers` and use public API to get values from the request object.  This enables users to mix `Rack::Request::Helpers` in to their own objects so they can implement `(get|set|fetch|each)_header` as they see fit (for example a proxy object).
- Files and directories with + in the name are served correctly. Rather than unescaping paths like a form, we unescape with a URI parser using `Rack::Utils.unescape_path`. Fixes #265
- Tempfiles are automatically closed in the case that there were too
	many posted.
- Added methods for manipulating response headers that don't assume
	they're stored as a Hash. Response-like classes may include the
	Rack::Response::Helpers module if they define these methods:
    - Rack::Response#has_header?
	- Rack::Response#get_header
	- Rack::Response#set_header
	- Rack::Response#delete_header
- Introduce Util.get_byte_ranges that will parse the value of the HTTP_RANGE string passed to it without depending on the `env` hash. `byte_ranges` is deprecated in favor of this method.
- Change Session internals to use Request objects for looking up session information. This allows us to only allocate one request object when dealing with session objects (rather than doing it every time we need to manipulate cookies, etc).
- Add `Rack::Request#initialize_copy` so that the env is duped when the request gets duped.
- Added methods for manipulating request specific data.  This includes
	data set as CGI parameters, and just any arbitrary data the user wants
	to associate with a particular request.  New methods:
	 - Rack::Request#has_header?
	 - Rack::Request#get_header
	 - Rack::Request#fetch_header
	 - Rack::Request#each_header
	 - Rack::Request#set_header
	 - Rack::Request#delete_header
- lib/rack/utils.rb: add a method for constructing "delete" cookie
	headers.  This allows us to construct cookie headers without depending
	on the side effects of mutating a hash.
- Prevent extremely deep parameters from being parsed. CVE-2015-3225

## [1.6.1] 2015-05-06
  - Fix CVE-2014-9490, denial of service attack in OkJson 
  - Use a monotonic time for Rack::Runtime, if available 
  - RACK_MULTIPART_LIMIT changed to RACK_MULTIPART_PART_LIMIT (RACK_MULTIPART_LIMIT is deprecated and will be removed in 1.7.0)

## [1.5.3] 2015-05-06
  - Fix CVE-2014-9490, denial of service attack in OkJson
  - Backport bug fixes to 1.5 series 

## [1.6.0] 2014-01-18
  - Response#unauthorized? helper
  - Deflater now accepts an options hash to control compression on a per-request level
  - Builder#warmup method for app preloading
  - Request#accept_language method to extract HTTP_ACCEPT_LANGUAGE
  - Add quiet mode of rack server, rackup --quiet
  - Update HTTP Status Codes to RFC 7231
  - Less strict header name validation according to RFC 2616
  - SPEC updated to specify headers conform to RFC7230 specification
  - Etag correctly marks etags as weak
  - Request#port supports multiple x-http-forwarded-proto values
  - Utils#multipart_part_limit configures the maximum number of parts a request can contain
  - Default host to localhost when in development mode
  - Various bugfixes and performance improvements

## [1.5.2] 2013-02-07
  - Fix CVE-2013-0263, timing attack against Rack::Session::Cookie
  - Fix CVE-2013-0262, symlink path traversal in Rack::File
  - Add various methods to Session for enhanced Rails compatibility
  - Request#trusted_proxy? now only matches whole stirngs
  - Add JSON cookie coder, to be default in Rack 1.6+ due to security concerns
  - URLMap host matching in environments that don't set the Host header fixed
  - Fix a race condition that could result in overwritten pidfiles
  - Various documentation additions

## [1.4.5] 2013-02-07
  - Fix CVE-2013-0263, timing attack against Rack::Session::Cookie
  - Fix CVE-2013-0262, symlink path traversal in Rack::File

## [1.1.6, 1.2.8, 1.3.10] 2013-02-07
  - Fix CVE-2013-0263, timing attack against Rack::Session::Cookie

## [1.5.1] 2013-01-28
  - Rack::Lint check_hijack now conforms to other parts of SPEC
  - Added hash-like methods to Abstract::ID::SessionHash for compatibility
  - Various documentation corrections

## [1.5.0] 2013-01-21
  - Introduced hijack SPEC, for before-response and after-response hijacking
  - SessionHash is no longer a Hash subclass
  - Rack::File cache_control parameter is removed, in place of headers options
  - Rack::Auth::AbstractRequest#scheme now yields strings, not symbols
  - Rack::Utils cookie functions now format expires in RFC 2822 format
  - Rack::File now has a default mime type
  - rackup -b 'run Rack::File.new(".")', option provides command line configs
  - Rack::Deflater will no longer double encode bodies
  - Rack::Mime#match? provides convenience for Accept header matching
  - Rack::Utils#q_values provides splitting for Accept headers
  - Rack::Utils#best_q_match provides a helper for Accept headers
  - Rack::Handler.pick provides convenience for finding available servers
  - Puma added to the list of default servers (preferred over Webrick)
  - Various middleware now correctly close body when replacing it
  - Rack::Request#params is no longer persistent with only GET params
  - Rack::Request#update_param and #delete_param provide persistent operations
  - Rack::Request#trusted_proxy? now returns true for local unix sockets
  - Rack::Response no longer forces Content-Types
  - Rack::Sendfile provides local mapping configuration options
  - Rack::Utils#rfc2109 provides old netscape style time output
  - Updated HTTP status codes
  - Ruby 1.8.6 likely no longer passes tests, and is no longer fully supported

## [1.4.4, 1.3.9, 1.2.7, 1.1.5] 2013-01-13
  - [SEC] Rack::Auth::AbstractRequest no longer symbolizes arbitrary strings
  - Fixed erroneous test case in the 1.3.x series

## [1.4.3] 2013-01-07
  - Security: Prevent unbounded reads in large multipart boundaries

## [1.3.8] 2013-01-07
  - Security: Prevent unbounded reads in large multipart boundaries

## [1.4.2] 2013-01-06
  - Add warnings when users do not provide a session secret
  - Fix parsing performance for unquoted filenames
  - Updated URI backports
  - Fix URI backport version matching, and silence constant warnings
  - Correct parameter parsing with empty values
  - Correct rackup '-I' flag, to allow multiple uses
  - Correct rackup pidfile handling
  - Report rackup line numbers correctly
  - Fix request loops caused by non-stale nonces with time limits
  - Fix reloader on Windows
  - Prevent infinite recursions from Response#to_ary
  - Various middleware better conforms to the body close specification
  - Updated language for the body close specification
  - Additional notes regarding ECMA escape compatibility issues
  - Fix the parsing of multiple ranges in range headers
  - Prevent errors from empty parameter keys
  - Added PATCH verb to Rack::Request
  - Various documentation updates
  - Fix session merge semantics (fixes rack-test)
  - Rack::Static :index can now handle multiple directories
  - All tests now utilize Rack::Lint (special thanks to Lars Gierth)
  - Rack::File cache_control parameter is now deprecated, and removed by 1.5
  - Correct Rack::Directory script name escaping
  - Rack::Static supports header rules for sophisticated configurations
  - Multipart parsing now works without a Content-Length header
  - New logos courtesy of Zachary Scott!
  - Rack::BodyProxy now explicitly defines #each, useful for C extensions
  - Cookies that are not URI escaped no longer cause exceptions

## [1.3.7] 2013-01-06
  - Add warnings when users do not provide a session secret
  - Fix parsing performance for unquoted filenames
  - Updated URI backports
  - Fix URI backport version matching, and silence constant warnings
  - Correct parameter parsing with empty values
  - Correct rackup '-I' flag, to allow multiple uses
  - Correct rackup pidfile handling
  - Report rackup line numbers correctly
  - Fix request loops caused by non-stale nonces with time limits
  - Fix reloader on Windows
  - Prevent infinite recursions from Response#to_ary
  - Various middleware better conforms to the body close specification
  - Updated language for the body close specification
  - Additional notes regarding ECMA escape compatibility issues
  - Fix the parsing of multiple ranges in range headers

## [1.2.6] 2013-01-06
  - Add warnings when users do not provide a session secret
  - Fix parsing performance for unquoted filenames

## [1.1.4] 2013-01-06
  - Add warnings when users do not provide a session secret

## [1.4.1] 2012-01-22
  - Alter the keyspace limit calculations to reduce issues with nested params
  - Add a workaround for multipart parsing where files contain unescaped "%"
  - Added Rack::Response::Helpers#method_not_allowed? (code 405)
  - Rack::File now returns 404 for illegal directory traversals
  - Rack::File now returns 405 for illegal methods (non HEAD/GET)
  - Rack::Cascade now catches 405 by default, as well as 404
  - Cookies missing '--' no longer cause an exception to be raised
  - Various style changes and documentation spelling errors
  - Rack::BodyProxy always ensures to execute its block
  - Additional test coverage around cookies and secrets
  - Rack::Session::Cookie can now be supplied either secret or old_secret
  - Tests are no longer dependent on set order
  - Rack::Static no longer defaults to serving index files
  - Rack.release was fixed

## [1.4.0] 2011-12-28
  - Ruby 1.8.6 support has officially been dropped. Not all tests pass.
  - Raise sane error messages for broken config.ru
  - Allow combining run and map in a config.ru
  - Rack::ContentType will not set Content-Type for responses without a body
  - Status code 205 does not send a response body
  - Rack::Response::Helpers will not rely on instance variables
  - Rack::Utils.build_query no longer outputs '=' for nil query values
  - Various mime types added
  - Rack::MockRequest now supports HEAD
  - Rack::Directory now supports files that contain RFC3986 reserved chars
  - Rack::File now only supports GET and HEAD requests
  - Rack::Server#start now passes the block to Rack::Handler::<h>#run
  - Rack::Static now supports an index option
  - Added the Teapot status code
  - rackup now defaults to Thin instead of Mongrel (if installed)
  - Support added for HTTP_X_FORWARDED_SCHEME
  - Numerous bug fixes, including many fixes for new and alternate rubies

## [1.1.3] 2011-12-28
  - Security fix. http://www.ocert.org/advisories/ocert-2011-003.html
    Further information here: http://jruby.org/2011/12/27/jruby-1-6-5-1

## [1.3.5] 2011-10-17
  - Fix annoying warnings caused by the backport in 1.3.4

## [1.3.4] 2011-10-01
  - Backport security fix from 1.9.3, also fixes some roundtrip issues in URI
  - Small documentation update
  - Fix an issue where BodyProxy could cause an infinite recursion
  - Add some supporting files for travis-ci

## [1.2.4] 2011-09-16
  - Fix a bug with MRI regex engine to prevent XSS by malformed unicode

## [1.3.3] 2011-09-16
  - Fix bug with broken query parameters in Rack::ShowExceptions
  - Rack::Request#cookies no longer swallows exceptions on broken input
  - Prevents XSS attacks enabled by bug in Ruby 1.8's regexp engine
  - Rack::ConditionalGet handles broken If-Modified-Since helpers

## [1.3.2] 2011-07-16
  - Fix for Rails and rack-test, Rack::Utils#escape calls to_s

## [1.3.1] 2011-07-13
  - Fix 1.9.1 support
  - Fix JRuby support
  - Properly handle $KCODE in Rack::Utils.escape
  - Make method_missing/respond_to behavior consistent for Rack::Lock,
    Rack::Auth::Digest::Request and Rack::Multipart::UploadedFile
  - Reenable passing rack.session to session middleware
  - Rack::CommonLogger handles streaming responses correctly
  - Rack::MockResponse calls close on the body object
  - Fix a DOS vector from MRI stdlib backport

## [1.2.3] 2011-05-22
  - Pulled in relevant bug fixes from 1.3
  - Fixed 1.8.6 support

## [1.3.0] 2011-05-22
  - Various performance optimizations
  - Various multipart fixes
  - Various multipart refactors
  - Infinite loop fix for multipart
  - Test coverage for Rack::Server returns
  - Allow files with '..', but not path components that are '..'
  - rackup accepts handler-specific options on the command line
  - Request#params no longer merges POST into GET (but returns the same)
  - Use URI.encode_www_form_component instead. Use core methods for escaping.
  - Allow multi-line comments in the config file
  - Bug L#94 reported by Nikolai Lugovoi, query parameter unescaping.
  - Rack::Response now deletes Content-Length when appropriate
  - Rack::Deflater now supports streaming
  - Improved Rack::Handler loading and searching
  - Support for the PATCH verb
  - env['rack.session.options'] now contains session options
  - Cookies respect renew
  - Session middleware uses SecureRandom.hex

## [1.2.2, 1.1.2] 2011-03-13
  - Security fix in Rack::Auth::Digest::MD5: when authenticator
    returned nil, permission was granted on empty password.

## [1.2.1] 2010-06-15
  - Make CGI handler rewindable
  - Rename spec/ to test/ to not conflict with SPEC on lesser
    operating systems

## [1.2.0] 2010-06-13
  - Removed Camping adapter: Camping 2.0 supports Rack as-is
  - Removed parsing of quoted values
  - Add Request.trace? and Request.options?
  - Add mime-type for .webm and .htc
  - Fix HTTP_X_FORWARDED_FOR
  - Various multipart fixes
  - Switch test suite to bacon

## [1.1.0] 2010-01-03
  - Moved Auth::OpenID to rack-contrib.
  - SPEC change that relaxes Lint slightly to allow subclasses of the
    required types
  - SPEC change to document rack.input binary mode in greator detail
  - SPEC define optional rack.logger specification
  - File servers support X-Cascade header
  - Imported Config middleware
  - Imported ETag middleware
  - Imported Runtime middleware
  - Imported Sendfile middleware
  - New Logger and NullLogger middlewares
  - Added mime type for .ogv and .manifest.
  - Don't squeeze PATH_INFO slashes
  - Use Content-Type to determine POST params parsing
  - Update Rack::Utils::HTTP_STATUS_CODES hash
  - Add status code lookup utility
  - Response should call #to_i on the status
  - Add Request#user_agent
  - Request#host knows about forwared host
  - Return an empty string for Request#host if HTTP_HOST and
    SERVER_NAME are both missing
  - Allow MockRequest to accept hash params
  - Optimizations to HeaderHash
  - Refactored rackup into Rack::Server
  - Added Utils.build_nested_query to complement Utils.parse_nested_query
  - Added Utils::Multipart.build_multipart to complement
    Utils::Multipart.parse_multipart
  - Extracted set and delete cookie helpers into Utils so they can be
    used outside Response
  - Extract parse_query and parse_multipart in Request so subclasses
    can change their behavior
  - Enforce binary encoding in RewindableInput
  - Set correct external_encoding for handlers that don't use RewindableInput

## [1.0.1] 2009-10-18
  - Bump remainder of rack.versions.
  - Support the pure Ruby FCGI implementation.
  - Fix for form names containing "=": split first then unescape components
  - Fixes the handling of the filename parameter with semicolons in names.
  - Add anchor to nested params parsing regexp to prevent stack overflows
  - Use more compatible gzip write api instead of "<<".
  - Make sure that Reloader doesn't break when executed via ruby -e
  - Make sure WEBrick respects the :Host option
  - Many Ruby 1.9 fixes.

## [1.0.0] 2009-04-25
  - SPEC change: Rack::VERSION has been pushed to [1,0].
  - SPEC change: header values must be Strings now, split on "\n".
  - SPEC change: Content-Length can be missing, in this case chunked transfer
    encoding is used.
  - SPEC change: rack.input must be rewindable and support reading into
    a buffer, wrap with Rack::RewindableInput if it isn't.
  - SPEC change: rack.session is now specified.
  - SPEC change: Bodies can now additionally respond to #to_path with
    a filename to be served.
  - NOTE: String bodies break in 1.9, use an Array consisting of a
    single String instead.
  - New middleware Rack::Lock.
  - New middleware Rack::ContentType.
  - Rack::Reloader has been rewritten.
  - Major update to Rack::Auth::OpenID.
  - Support for nested parameter parsing in Rack::Response.
  - Support for redirects in Rack::Response.
  - HttpOnly cookie support in Rack::Response.
  - The Rakefile has been rewritten.
  - Many bugfixes and small improvements.

## [0.9.1] 2009-01-09
  - Fix directory traversal exploits in Rack::File and Rack::Directory.

## [0.9] 2009-01-06
  - Rack is now managed by the Rack Core Team.
  - Rack::Lint is stricter and follows the HTTP RFCs more closely.
  - Added ConditionalGet middleware.
  - Added ContentLength middleware.
  - Added Deflater middleware.
  - Added Head middleware.
  - Added MethodOverride middleware.
  - Rack::Mime now provides popular MIME-types and their extension.
  - Mongrel Header now streams.
  - Added Thin handler.
  - Official support for swiftiplied Mongrel.
  - Secure cookies.
  - Made HeaderHash case-preserving.
  - Many bugfixes and small improvements.

## [0.4] 2008-08-21
  - New middleware, Rack::Deflater, by Christoffer Sawicki.
  - OpenID authentication now needs ruby-openid 2.
  - New Memcache sessions, by blink.
  - Explicit EventedMongrel handler, by Joshua Peek <josh@joshpeek.com>
  - Rack::Reloader is not loaded in rackup development mode.
  - rackup can daemonize with -D.
  - Many bugfixes, especially for pool sessions, URLMap, thread safety
    and tempfile handling.
  - Improved tests.
  - Rack moved to Git.

## [0.3] 2008-02-26
  - LiteSpeed handler, by Adrian Madrid.
  - SCGI handler, by Jeremy Evans.
  - Pool sessions, by blink.
  - OpenID authentication, by blink.
  - :Port and :File options for opening FastCGI sockets, by blink.
  - Last-Modified HTTP header for Rack::File, by blink.
  - Rack::Builder#use now accepts blocks, by Corey Jewett.
    (See example/protectedlobster.ru)
  - HTTP status 201 can contain a Content-Type and a body now.
  - Many bugfixes, especially related to Cookie handling.

## [0.2] 2007-05-16
  - HTTP Basic authentication.
  - Cookie Sessions.
  - Static file handler.
  - Improved Rack::Request.
  - Improved Rack::Response.
  - Added Rack::ShowStatus, for better default error messages.
  - Bug fixes in the Camping adapter.
  - Removed Rails adapter, was too alpha.

## [0.1] 2007-03-03
