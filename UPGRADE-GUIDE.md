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

## Response body might not respond to `#each`

Rack 3 has more strict requirements on response bodies. Previously, response body would only need to respond to `#each` and optionally `#close`. In addition, there was no way to determine whether it was safe to call `#each` and buffer the response.

It is generally only safe to buffer a response body if it responds to `#to_ary`.
