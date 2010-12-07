module Rack
  # This module contains frozen singleton copies of all standard HTTP response headers.
  module HTTP_HEADER
    ACCEPT = "Accept".freeze
    ACCEPT_RANGES = "Accept-Ranges".freeze
    AGE = "Age".freeze
    ALLOW = "Allow".freeze
    AUTHORIZATION = "Authorization".freeze
    CACHE_CONTROL = "Cache-Control".freeze
    CONTENT_DISPOSITION = "Content-Disposition".freeze
    CONTENT_ENCODING = "Content-Encoding".freeze
    CONTENT_LANGUAGE = "Content-Language".freeze
    CONTENT_LENGTH = "Content-Length".freeze
    CONTENT_LOCATION = "Content-Location".freeze
    CONTENT_MD5 = "Content-MD5".freeze
    CONTENT_RANGE = "Content-Range".freeze
    CONTENT_TYPE = "Content-Type".freeze
    DATE = "Date".freeze
    ETAG = "ETag".freeze
    EXPIRES = "Expires".freeze
    LAST_MODIFIED = "Last-Modified".freeze
    LOCATION = "Location".freeze
    PRAGMA = "Pragma".freeze
    PROXY_AUTHENTICATE = "Proxy-Authenticate".freeze
    REFRESH = "REFRESH".freeze
    RETRY_AFTER = "Retry-After".freeze
    SERVER = "Server".freeze
    SET_COOKIE = "Set-Cookie".freeze
    TRAILER = "Trailer".freeze
    TRANSFER_ENCODING = "Transfer-Encoding".freeze
    UPGRADE = "Upgrade".freeze
    VARY = "Vary".freeze
    VIA = "Via".freeze
    WARNING = "Warning".freeze
    WWW_AUTHENTICATE = "WWW-Authenticate".freeze
    X_CASCADE = "X-Cascade".freeze
  end
end
