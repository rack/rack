module Rack
  # This module contains frozen singleton copies of all HTTP request methods.
  module HTTP_METHOD
    HEAD = "HEAD".freeze
    GET = "GET".freeze
    POST = "POST".freeze
    PUT = "PUT".freeze
    DELETE = "DELETE".freeze
    OPTIONS = "OPTIONS".freeze
    TRACE = "TRACE".freeze
  end
end
