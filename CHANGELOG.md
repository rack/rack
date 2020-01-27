## [2.1.2] - 2020-01-27

- Fix multipart parser for some files to prevent denial of service ([@aiomaster](https://github.com/aiomaster))
- Fix `Rack::Builder#use` with keyword arguments ([@kamipo](https://github.com/kamipo))
- Skip deflating in Rack::Deflater if Content-Length is 0 ([@jeremyevans](https://github.com/jeremyevans))
- Remove `SessionHash#transform_keys`, no longer needed ([@pavel](https://github.com/pavel))
- Add to_hash to wrap Hash and Session classes ([@oleh-demyanyuk](https://github.com/oleh-demyanyuk))
- Handle case where session id key is requested but missing ([@jeremyevans](https://github.com/jeremyevans))

## [2.1.1] - 2020-01-12

- Remove `Rack::Chunked` from `Rack::Server` default middleware. ([#1475](https://github.com/rack/rack/pull/1475), [@ioquatix](https://github.com/ioquatix))

## [2.1.0] - 2020-01-10

### Added

- Add support for `SameSite=None` cookie value. ([@hennikul](https://github.com/hennikul))
- Add trailer headers. ([@eileencodes](https://github.com/eileencodes))
- Add MIME Types for video streaming. ([@styd](https://github.com/styd))
- Add MIME Type for WASM. ([@buildrtech](https://github.com/buildrtech))
- Add `Early Hints(103)` to status codes. ([@egtra](https://github.com/egtra))
- Add `Too Early(425)` to status codes. ([@y-yagi]((https://github.com/y-yagi)))
- Add `Bandwidth Limit Exceeded(509)` to status codes. ([@CJKinni](https://github.com/CJKinni))
- Add method for custom `ip_filter`. ([@svcastaneda](https://github.com/svcastaneda))
- Add boot-time profiling capabilities to `rackup`. ([@tenderlove](https://github.com/tenderlove))
- Add multi mapping support for `X-Accel-Mappings` header. ([@yoshuki](https://github.com/yoshuki))
- Add `sync: false` option to `Rack::Deflater`. (Eric Wong)
- Add `Builder#freeze_app` to freeze application and all middleware instances. ([@jeremyevans](https://github.com/jeremyevans))
- Add API to extract cookies from `Rack::MockResponse`. ([@petercline](https://github.com/petercline))

### Changed

- Don't propagate nil values from middleware. ([@ioquatix](https://github.com/ioquatix))
- Lazily initialize the response body and only buffer it if required. ([@ioquatix](https://github.com/ioquatix))
- Fix deflater zlib buffer errors on empty body part. ([@felixbuenemann](https://github.com/felixbuenemann))
- Set `X-Accel-Redirect` to percent-encoded path. ([@diskkid](https://github.com/diskkid))
- Remove unnecessary buffer growing when parsing multipart. ([@tainoe](https://github.com/tainoe))
- Expand the root path in `Rack::Static` upon initialization. ([@rosenfeld](https://github.com/rosenfeld))
- Make `ShowExceptions` work with binary data. ([@axyjo](https://github.com/axyjo))
- Use buffer string when parsing multipart requests. ([@janko-m](https://github.com/janko-m))
- Support optional UTF-8 Byte Order Mark (BOM) in config.ru. ([@mikegee](https://github.com/mikegee))
- Handle `X-Forwarded-For` with optional port. ([@dpritchett](https://github.com/dpritchett))
- Use `Time#httpdate` format for Expires, as proposed by RFC 7231. ([@nanaya](https://github.com/nanaya))
- Make `Utils.status_code` raise an error when the status symbol is invalid instead of `500`. ([@adambutler](https://github.com/adambutler))
- Rename `Request::SCHEME_WHITELIST` to `Request::ALLOWED_SCHEMES`.
- Make `Multipart::Parser.get_filename` accept files with `+` in their name. ([@lucaskanashiro](https://github.com/lucaskanashiro))
- Add Falcon to the default handler fallbacks. ([@ioquatix](https://github.com/ioquatix))
- Update codebase to avoid string mutations in preparation for `frozen_string_literals`. ([@pat](https://github.com/pat))
- Change `MockRequest#env_for` to rely on the input optionally responding to `#size` instead of `#length`. ([@janko](https://github.com/janko))
- Rename `Rack::File` -> `Rack::Files` and add deprecation notice. ([@postmodern](https://github.com/postmodern)).
- Prefer Base64 “strict encoding” for Base64 cookies. ([@ioquatix](https://github.com/ioquatix))

### Removed

- Remove `to_ary` from Response ([@tenderlove](https://github.com/tenderlove))
- Deprecate `Rack::Session::Memcache` in favor of `Rack::Session::Dalli` from dalli gem ([@fatkodima](https://github.com/fatkodima))

### Fixed

- Eliminate warnings for Ruby 2.7. ([@osamtimizer](https://github.com/osamtimizer]))

### Documentation

- Update broken example in `Session::Abstract::ID` documentation. ([tonytonyjan](https://github.com/tonytonyjan))
- Add Padrino to the list of frameworks implmenting Rack. ([@wikimatze](https://github.com/wikimatze))
- Remove Mongrel from the suggested server options in the help output. ([@tricknotes](https://github.com/tricknotes))
- Replace `HISTORY.md` and `NEWS.md` with `CHANGELOG.md`. ([@twitnithegirl](https://github.com/twitnithegirl))
- CHANGELOG updates. ([@drenmi](https://github.com/Drenmi), [@p8](https://github.com/p8))
