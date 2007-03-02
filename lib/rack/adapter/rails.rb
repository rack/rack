unless defined? RAILS_ROOT
  raise "Rails' environment has to be loaded before using Rack::Adapter::Rails"
end

require "dispatcher"

module Rack
  module Adapter
    # TODO: Extract this
    class Rails < Cascade
      def initialize
        file = Rack::File.new(::File.join(RAILS_ROOT, "public"))
        dispatcher = RailsDispatcher.new
        
        super([file, dispatcher])
      end
    end
    
    class RailsDispatcher
      def call(env)
        response = dispatch(CGIStub.new(env))
        headers  = response.headers
        status   = headers.delete("Status")
        
        [ status, headers, response.body ]
      end
      
      protected
      
      def dispatch(cgi)
        session_options = ActionController::CgiRequest::DEFAULT_SESSION_OPTIONS

        request  = ActionController::CgiRequest.new(cgi, session_options)
        response = ActionController::CgiResponse.new(cgi)

        Dispatcher.send(:prepare_application)

        controller = ActionController::Routing::Routes.recognize(request)
        controller.process(request, response)

        return response
      end
      
      class RailsDispatcher::CGIStub
        def initialize(env)
          @request = Request.new(env)
        end
        
        def env_table()    @request.env          end
        def params()       @request.params       end
        def cookies()      @request.cookies      end
        def query_string() @request.query_string end
          
        def [](key)
          # FIXME: This is probably just wrong
          @request.env[key] || @request.cookies[key]
        end

        def key?(key)
          self[key] ? true : false
        end
      end
    end
  end
end