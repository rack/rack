# AUTHOR: blink <blinketje@gmail.com>; blink#ruby-lang@irc.freenode.net

gem 'ruby-openid', '>= 2.0.0' if defined? Gem
require 'rack/auth/abstract/handler'
require 'openid'
require 'openid/store/memory'
require 'uri'
require 'pp'

module Rack
  module Auth
    # Rack::Auth::OpenID provides a simple method for permitting
    # openid based logins. It requires the ruby-openid library from
    # janrain to operate, as well as some method of session management.
    #
    # It is recommended to read through the OpenID spec, as well as
    # ruby-openid's documentation, to understand what exactly goes on. However
    # a setup as simple as that in the example is enough to provide
    # functionality.
    #
    # This library strongly orients itself to utilize the openid 2.0 features
    # of the ruby-openid library, while maintaining openid 1.0 compatiblity.
    #
    # NOTE: Due to the amount of data that this library stores in the
    # session, Rack::Session::Cookie may fault.
    class OpenID2 < AbstractHandler
      # Required for ruby-openid
      OIDStore = ::OpenID::Store::Memory.new
      HTML = '<html><head><title>%s</title></head><body>%s</body></html>'

      # A Hash of options is taken as it's single initializing
      # argument. For example:
      #
      #   oid = OpenID.new({
      #     'http://openid.net/sreg/1.0' => { 'required' => 'nickname' },
      #     :return_to => 'http://mysite.com/openid',
      #     :realm => 'http://mysite.com/'
      #   })
      #   Rack::URLMap.new {
      #     '/openid' => oid,
      #     ...
      #   }
      #   ...
      #
      # -- Options
      #
      # :realm defines the realm identifying the site they are trusting with
      # their identity. This is a required value.
      #
      # :return_to defines the url to return to after the client authenticates
      # with the openid service provider. This url should point to where
      # Rack::Auth::OpenID is mounted. If :return_to is not provided, the
      # return url for the openid request will be the url at which the request
      # takes place.
      #
      # NOTE: In OpenID 1.x, the realm or trust_root is optional and the
      # return_to url is required. As this library strives tward ruby-openid
      # compatibiliy the realm is required and return_to is optional.
      #
      # :post_login is the url to go to after the authentication process
      # has completed. If unset the HTTP_REFERER to the initial logon request
      # is used, if there is no referer then the :realm url is used.
      #
      # :session_key defines the key to the session hash in the
      # env. It defaults to 'rack.session'.
      #
      # :openid_param Defines at what key in the params to find the identifier
      # to resolve. As per the 2.0 spec, the default is 'openid_identifier'.
      def initialize(options={})
        raise ArgumentError, 'No realm provided.' unless options.key? :realm
        realm = URI(options[:realm])
        raise ArgumentError, 'Invalid realm path.' if realm.path.empty?

        if options[:return_to] and ruri = URI(options[:return_to])
          raise ArgumentError, 'Invalid return_to path.' if ruri.path.empty?
          good = realm.path == ruri.path[0,realm.path.size]
          raise ArgumentError, 'return_to not within realm.' unless good
        end

        if options.has_key? :extensions
          good = options[:extensions].all?{|e| e.is_a? ::OpenID::Extension }
          raise ArgumentError, 'Non-extension object.' unless good
        end

        @options = {
          :session_key => 'rack.session',
          :openid_param => 'openid_identifier',
          :bare_login => HTML % ['OpenID Login',<<-LOG]
  <form>
    OpenID:
    <input type='text' name='openid_identifier' />
    <input type='submit' value='Login' />
  </form>
          LOG
        }.merge(options)
      end

      def call(env)
        env['rack.auth.openid'] = self
        return no_session unless session = env[@options[:session_key]]
        session[:openid] = {} unless session[:openid].is_a? Hash
        session = session[:openid] # let us work in our own namespace...

        request = Rack::Request.new env
        consumer = ::OpenID::Consumer.new session, OIDStore

        if request.params[@options[:openid_param]]
          check consumer, session, request
        elsif request.params['openid.mode']
          finish consumer, session, request
        elsif !request.params.empty?
          env['rack.errors'].puts "No valid params provided."
          bad_request
        else
          [200, {'Content-Type'=>'text/html'}, @options[:bare_login]]
        end
      rescue
        env['rack.errors'].puts $!.message
        bad_request
      end

      def check(consumer, session, req)
        oid = consumer.begin(req.params[@options[:openid_param]])
        req.env['rack.auth.openid.request'] = oid

        @options.each do |opt,arg|
          case opt
          when Module
            next unless ::OpenID::Extension > opt::Request
            oid.add_extension(opt::Request.new(*arg[0]))
          when String
            raise 'No longer supporting old interface due to fail'
            arg.each do |k,v|
              oid.add_extension_arg(opt, k, v)
            end
          end
        end

        query_args = @options.values_at(:realm, :return_to, :immediate)

        session[:site_return]   = @options[:post_login]
        session[:site_return] ||= req.env['HTTP_REFERER']

        pp oid if $DEBUG
        if oid.send_redirect?(*query_args)
          [ 303, {'Location'=>oid.redirect_url(*query_args)}, [] ]
        else
          body = BASIC_HTML % ['Confirm...', oid.form_markup(*query_args)]
          [ 200, {'Content-Type'=>'text/html'}, body.to_a ]
        end
      rescue ::OpenID::DiscoveryFailure => e
        # thrown from inside OpenID::Consumer#begin, which would be in #check
        env['rack.errors'].puts $!.message
        auth_fail
      end

      def finish(consumer, session, req)
        oid = consumer.complete(req.params, req.url)
        req.env['rack.auth.openid.response'] = oid
        pp oid if $DEBUG

        case oid.status
        when :success
          site_return   = session.delete :site_return
          site_return ||= @options[:realm]

          # Remove remnant cache data
          session.clear
          # Value for unique identification and such
          session['identity'] = oid.identity_url
          # Value for display and UI labels
          session['display_identifier'] = oid.display_identifier

          # Then we include all the extension gathered data
          @options.each do |opt,arg|
            case opt
            when Module
              next unless ::OpenID::Extension > opt::Response
              r = opt::Response.from_success_response(oid,*arg[1])
              session.merge! r.get_extension_args
            when String
              raise 'No longer supporting old interface due to fail'
              if $DEBUG
                pp [opt, arg]
                pp oid.extension_response(opt,false)
                pp oid.message.get_args(opt)
              end
            end
          end

          [ 303, {'Location'=>site_return}, [] ]
        when :failure
          req.env['rack.errors'].puts oid.message
          bad_login
        when :cancel
          site_return = session.delete :site_return
          site_return ||= @options[:realm]
          session.clear
          [ 303, {'Location'=>site_return}, [] ]
        when :setup_needed
          body = BASIC_HTML % ['Setup required', '<p>Setup required</p>']
          [ 200, {'Content-Type'=>'text/html'}, body.to_a ]
        end
      end

      def no_session
        @options.
          fetch :no_session, [ 500,
            {'Content-Type'=>'text/plain'},
            'No session available.' ]
      end

      def auth_fail
        @options.
          fetch :auth_fail, [ 500,
            {'Content-Type'=>'text/plain'},
            'Foreign server failure.' ]
      end

      def bad_login
        @options.
          fetch :bad_login, [ 401,
            {'Content-Type'=>'text/plain'},
            'Identification has failed.' ]
      end
    end
  end
end
