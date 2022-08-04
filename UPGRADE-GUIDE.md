# Rack 3 Upgrade Guide

This document is a work in progress, but outlines some of the key changes in Rack 3 which you should be aware of in order to update your server, middleware and/or applications.

## Lower Case Headers

Rack 3 requires all response headers to be lower case. This is to simplify handling response headers.

## Headers must be a hash

Rack 3 requires response headers to be a mutable hash. Previously it could be any object that would respond to `#each` and yield `key`/`value` pairs.

## Multiple response header values are encoded using an `Array`

Response header values can be an Array to handle multiple values (and no longer supports `\n` encoded headers). If you use `Rack::Response`, you don't need to do anything, but if manually append values to response headers, you will need to promote them to an Array, e.g.

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

## Response must be mutable

Rack 3 requires the response Array `[status, headers, body]` to be mutable.

## Response body ##

Rack 3 supports a streaming mode for the response body and has some additional requirements compared to previous versions which might lead to some issues while upgrading.

### Implementing `#to_ary` ###

If your body responds to `#to_ary` then it must return an `Array` whose contents are identical to that produced by calling `#each`. If the body responds to both `#to_ary and `#close` then its implementation of `#to_ary` must also call `#close`.

### Middleware ###

Be aware that the response body might not respond to `#each` and you must now check if the body responds to `#each` or not to determine if it is an enumerable or streaming body.

You must not call `#each` directly on the body and instead you should return a new body that calls `#each` on the original body and yields at least once per iteration.
