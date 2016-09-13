require 'rack/lobster'

stack = Rack::MiddlewareStack.new
stack.use Rack::Chunked
stack.use Rack::ShowExceptions

use stack

run Rack::Lobster.new
