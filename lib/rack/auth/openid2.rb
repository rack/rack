# AUTHOR: blink <blinketje@gmail.com>; blink#ruby-lang@irc.freenode.net

gem 'ruby-openid', '>= 2.0.0' if defined? Gem
require 'rack/auth/abstract/handler' #rack
require 'uri' #std
require 'pp' #std
require 'openid' #gem
require 'openid/store/memory' #gem

module Rack
  module Auth
    # Rack::Auth::OpenID provides a simple method for permitting
    # openid based logins. It requires the ruby-openid library from
    # janrain to operate, as well as a rack method of session management.
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
      class NoSession < RuntimeError; end
      # Required for ruby-openid
      OIDStore = ::OpenID::Store::Memory.new
      HTML = '<html><head><title>%s</title></head><body>%s</body></html>'

      # A Hash of options is taken as it's single initializing
      # argument. For example:
      #
      #   simple_oid = OpenID2.new('http://mysite.com/')
      #
      #   return_oid = OpenID2.new('http://mysite.com/',
      #     :return_to => 'http://mysite.com/openid'
      #   )
      #
      # -- Arguments
      #
      # The first argument is the realm, identifying the site they are trusting
      # with their identity. This is required.
      #
      # :return_to defines the url to return to after the client authenticates
      # with the openid service provider. This url should point to where
      # Rack::Auth::OpenID is mounted. If :return_to is not provided, the
      # return url for the openid request will be the url at which the request
      # takes place.
      #
      # NOTE: In OpenID 1.x, the realm or trust_root is optional and the
      # return_to url is required. As this library strives tward ruby-openid,
      # and OpenID 2.0 compatibiliy, the realm is required and return_to is
      # optional. However, this implementation is still backwards compatible
      # with OpenID 1.0 servers.
      #
      # :post_login is the url to go to after the authentication process
      # has completed. If unset the HTTP_REFERER to the initial logon request
      # is used, if there is no referer then the realm url is used. See #check.
      #
      # :session_key defines the key to the session hash in the
      # env. It defaults to 'rack.session'.
      #
      # :openid_param Defines at what key in the params to find the identifier
      # to resolve. As per the 2.0 spec, the default is 'openid_identifier'.
      def initialize(realm, options={})
        @realm = realm
        realm = URI(realm)
        raise ArgumentError, 'Invalid realm path.' if realm.path.empty?

        if options[:return_to] and ruri = URI(options[:return_to])
          raise ArgumentError, 'Invalid return_to path.' if ruri.path.empty?
          good = realm.path == ruri.path[0,realm.path.size]
          raise ArgumentError, 'return_to not within realm.' unless good
        end

        # TODO: extension support
        if options.has_key? :extensions
          warn "Extensions are not currently supported by Rack::Auth::OpenID2"
        end

        if options.has_key? :post_login
          post = URI(options[:post_login])
          raise ArgumentError, 'Invalid post_login uri.' unless post
        end

        @options = {
          :session_key => 'rack.session',
          :openid_param => 'openid_identifier',
          #:post_login,
          #:no_session, :bad_login, :auth_fail, :error
          :store => OIDStore,
          :immediate => false,
          :anonymous => false,
          :catch_errors => false
        }.merge(options)
      end

      attr_reader :options

      # It sets up and uses session data at :openid within the session. It
      # sets up the ::OpenID::Consumer using the store specified by
      # options[:store].
      #
      # If the parameter specified by options[:openid_param] is present,
      # processing is passed to #check and the result is returned.
      #
      # If the parameter 'openid.mode' is set, implying a followup from the
      # openid server, processing is passed to #finish and the result is
      # returned.
      #
      # If neither of these conditions are met, a 400 error is returned.
      #
      # If an error is thrown and options[:pass_errors] is false, 
      def call(env)
        env['rack.auth.openid'] = self
        session = env[@options[:session_key]]
        raise(NoSession, 'No compatible session') \
          unless session and session.is_a? Hash
        # let us work in our own namespace...
        session = (session[:openid] ||= {})

        request = Rack::Request.new env
        consumer = ::OpenID::Consumer.new session, @options[:store]

        if request.params[@options[:openid_param]]
          check consumer, session, request
        elsif request.params['openid.mode']
          finish consumer, session, request
        else
          env['rack.errors'].puts "No valid params provided."
          bad_request
        end
      rescue NoSession
        env['rack.errors'].puts($!.message, *$@)

        @options. ### Missing or incompatible session
          fetch :no_session, [ 500,
            {'Content-Type'=>'text/plain'},
            $!.message ]
      rescue
        env['rack.errors'].puts($!.message, *$@)

        raise($!) \
          unless @options[:catch_errors]
        @options.
          fetch :error, [ 500,
            {'Content-Type'=>'text/plain'},
            'OpenID has encountered an error.' ]
      end

      def check(consumer, session, req)
        session[:openid_param]  = req.params[@options[:openid_param]]
        oid = consumer.begin(session[:openid_param], @options[:anonymous])
        pp oid if $DEBUG
        req.env['rack.auth.openid.request'] = oid

        session[:site_return] ||= @options.
          fetch(:post_login, req.env['HTTP_REFERER'])

        # SETUP_NEEDED check!
        # see OpenID::Consumer::CheckIDRequest docs
        query_args = [@realm, *@options.values_at(:return_to, :immediate)]
        query_args[2] = false if session.key? :setup_needed
        pp query_args if $DEBUG

        if oid.send_redirect?(*query_args)
          redirect = oid.redirect_url(*query_args)
          [ 303, {'Location'=>redirect}, [] ]
        else
          # check on 'action' option.
          formbody = oid.form_markup(*query_args)
          body = HTML % ['Confirm...', formbody]
          [ 200, {'Content-Type'=>'text/html'}, body.to_a ]
        end
      rescue ::OpenID::DiscoveryFailure => e
        # thrown from inside OpenID::Consumer#begin by yadis stuff
        env['rack.errors'].puts($!.message, *$@)

        @options. ### Foreign server failed
          fetch :auth_fail, [ 503,
            {'Content-Type'=>'text/plain'},
            'Foreign server failure.' ]
      end

      def finish(consumer, session, req)
        oid = consumer.complete(req.params, req.url)
        pp oid if $DEBUG
        req.env['rack.auth.openid.response'] = oid

        site_return   = session.delete(:site_return)
        site_return ||= @realm

        case oid.status
        when ::OpenID::Consumer::FAILURE
          session.clear
          req.env['rack.errors'].puts oid.message

          @options. ### Bad Login
            fetch :bad_login, [ 401,
              {'Content-Type'=>'text/plain'},
              'Identification has failed.' ]
        when ::OpenID::Consumer::SUCCESS
          session.clear
          session['authenticated'] = true
          # Value for unique identification and such
          session['identity'] = oid.identity_url
          # Value for display and UI labels
          session['identifier'] = oid.display_identifier

          [ 303, {'Location'=>site_return}, ['Authentication successful.'] ]
        when ::OpenID::Consumer::CANCEL
          session.clear
          session['authenticated'] = false

          [ 303, {'Location'=>site_return}, ['Authentication cancelled.'] ]
        when ::OpenID::Consumer::SETUP_NEEDED
          session[:site_return] = site_return
          session[:setup_needed] = true
          raise('Required values missing.') \
            unless o_id = session[:openid_param]
          # repeat request to us, only not immediate
          repeat = req.script_name+
            '?'+@options[:openid_param]+
            '='+o_id

          [303, {'Location'=>repeat}, ['Reauthentication required.']]
        end
      end
    end
  end
end
