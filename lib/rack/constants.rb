module Rack
  module Const
    RACK_VERSION         = 'rack.version'.freeze
    RACK_INPUT           = 'rack.input'.freeze
    RACK_ERRORS          = 'rack.errors'.freeze
    RACK_MULTITHREAD     = 'rack.multithread'.freeze
    RACK_MULTIPROCESS    = 'rack.multiprocess'.freeze
    RACK_RUN_ONCE        = 'rack.run_once'.freeze
    RACK_URL_SCHEME      = 'rack.url_scheme'.freeze
    RACK_SESSION         = 'rack.session'.freeze
    RACK_SESSION_OPTIONS = 'rack.session.options'.freeze

    ENV_CONTENT_LENGTH         = 'CONTENT_LENGTH'.freeze
    ENV_CONTENT_TYPE           = 'CONTENT_TYPE'.freeze
    ENV_HTTPS                  = 'HTTPS'.freeze
    ENV_HTTP_ACCEPT_ENCODING   = 'HTTP_ACCEPT_ENCODING'.freeze
    ENV_HTTP_CONTENT_LENGTH    = 'HTTP_CONTENT_LENGTH'.freeze
    ENV_HTTP_CONTENT_TYPE      = 'HTTP_CONTENT_TYPE'.freeze
    ENV_HTTP_COOKIE            = 'HTTP_COOKIE'.freeze
    ENV_HTTP_HOST              = 'HTTP_HOST'.freeze
    ENV_HTTP_IF_MODIFIED_SINCE = 'HTTP_IF_MODIFIED_SINCE'.freeze
    ENV_HTTP_IF_NONE_MATCH     = 'HTTP_IF_NONE_MATCH'.freeze
    ENV_HTTP_PORT              = 'HTTP_PORT'.freeze
    ENV_HTTP_REFERER           = 'HTTP_REFERER'.freeze
    ENV_HTTP_VERSION           = 'HTTP_VERSION'.freeze
    ENV_HTTP_X_FORWARDED_FOR   = 'HTTP_X_FORWARDED_FOR'.freeze
    ENV_HTTP_X_REQUESTED_WITH  = 'HTTP_X_REQUESTED_WITH'.freeze
    ENV_PATH_INFO              = 'PATH_INFO'.freeze
    ENV_QUERY_STRING           = 'QUERY_STRING'.freeze
    ENV_REMOTE_ADDR            = 'REMOTE_ADDR'.freeze
    ENV_REMOTE_USER            = 'REMOTE_USER'.freeze
    ENV_REQUEST_METHOD         = 'REQUEST_METHOD'.freeze
    ENV_REQUEST_PATH           = 'REQUEST_PATH'.freeze
    ENV_REQUEST_URI            = 'REQUEST_URI'.freeze
    ENV_SCRIPT_NAME            = 'SCRIPT_NAME'.freeze
    ENV_SERVER_NAME            = 'SERVER_NAME'.freeze
    ENV_SERVER_PORT            = 'SERVER_PORT'.freeze
    ENV_SERVER_PROTOCOL        = 'SERVER_PROTOCOL'.freeze

    CACHE_CONTROL     = 'Cache-Control'.freeze
    CONTENT_ENCODING  = 'Content-Encoding'.freeze
    CONTENT_LENGTH    = 'Content-Length'.freeze
    CONTENT_TYPE      = 'Content-Type'.freeze
    DELETE            = 'DELETE'.freeze
    EMPTY_STRING      = ''.freeze
    ETAG              = 'Etag'.freeze
    GET               = 'GET'.freeze
    HEAD              = 'HEAD'.freeze
    LAST_MODIFIED     = 'Last-Modified'.freeze
    POST              = 'POST'.freeze
    PUT               = 'PUT'.freeze
    SLASH             = '/'.freeze
    TRANSFER_ENCODING = 'Transfer-Encoding'.freeze
  end
end
