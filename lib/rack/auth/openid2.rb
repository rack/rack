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
    # All responses from this rack application will be 303 redirects unless an
    # error occurs, or if the authentication request requires an HTML form
    # submission.
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
      #   page_oid = OpenID2.new('http://mysite.com/',
      #     :login_good => 'http://mysite.com/auth_good'
      #   )
      #
      # -- Arguments
      #
      # The first argument is the realm, identifying the site they are trusting
      # with their identity. This is required.
      #
      # The second and optional argument is a hash of options.
      #
      # -- Options
      #
      # :return_to defines the url to return to after the client authenticates
      # with the openid service provider. This url should point to where
      # Rack::Auth::OpenID is mounted. If :return_to is not provided, the url
      # will be derived within the ruby-openid implementation.
      #
      # NOTE: In OpenID 1.x, the realm or trust_root is optional and the
      # return_to url is required. As this library strives tward ruby-openid
      # 2.0, and OpenID 2.0 compatibiliy, the realm is required and return_to
      # is optional. However, this implementation is still backwards compatible
      # with OpenID 1.0 servers.
      #
      # :session_key defines the key to the session hash in the env. It
      # defaults to 'rack.session'.
      #
      # :openid_param defines at what key in the request parameters to find
      # the identifier to resolve. As per the 2.0 spec, the default is
      # 'openid_identifier'.
      #
      # :extensions will specify what extensions are to used with OpenID,
      # of which the format and support of which is yet to be completed.
      #
      # -- URL options
      #
      # :login_good is the url to go to after the authentication process
      # has completed.
      #
      # :login_fail is the url to go to after the authentication process
      # has failed.
      #
      # :login_fail is the url to go to after the authentication process
      # has been cancelled.
      #
      # -- Response options
      #
      # :no_session should be a rack response to be returned if no or an
      # incompatible session is found.
      #
      # :auth_fail should be a rack response to be returned if an
      # OpenID::DiscoveryFailure occurs. This is typically due to being
      # unable to access the identity url or identity server.
      #
      # :error should be a rack response to return if any other generic error
      # would occur AND options[:catch_errors] is true.
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

        [:login_good, :login_fail, :login_quit].each do |key|
          next unless options.key? key
          raise ArgumentError, "Invalid #{key} uri." unless URI(options[key])
        end

        @options = {
          :session_key => 'rack.session',
          :openid_param => 'openid_identifier',
          #:login_good, :login_fail, :login_quit
          #:no_session, :auth_fail, :error
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
      # If an error is thrown and options[:catch_errors] is false, the
      # exception will be reraised. Otherwise a 500 error is returned.
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

      # As the first part of OpenID consumer action, #check retrieves the
      # data required for completion.
      #
      # * session[:openid_param] is the request parameter requested to be
      #   authenticated.
      # * session[:site_return] is set as the request's HTTP_REFERER if
      #   previously unset.
      # * env['rack.auth.openid.request'] is the openid checkidrequest.
      def check(consumer, session, req)
        session[:openid_param]  = req.params[@options[:openid_param]]
        oid = consumer.begin(session[:openid_param], @options[:anonymous])
        pp oid if $DEBUG
        req.env['rack.auth.openid.request'] = oid

        session[:site_return] ||= req.env['HTTP_REFERER']

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
        req.env['rack.errors'].puts($!.message, *$@)

        @options. ### Foreign server failed
          fetch :auth_fail, [ 503,
            {'Content-Type'=>'text/plain'},
            'Foreign server failure.' ]
      end

      # This is the final part of authentication. Unless any errors outside of
      # specification occur, a 303 redirect will be returned with the location
      # determined by the OpenID response type. If none of the response type
      # :login_* urls are set, the redirect will be set to
      # session[:site_return]. If session[:site_return] is unset, the realm
      # will be used.
      #
      # Any messages from OpenID's response are appended to the response body.
      #
      # * env['rack.auth.openid.response'] is the openid response.
      #
      # The four valid possible outcomes are:
      #   * failure: options[:login_fail] or session[:site_return]
      #     * session[:openid] is cleared and any messages are send to rack.errors
      #     * session[:openid]['authenticated'] is false
      #   * success: options[:login_good] or session[:site_return]
      #     * session[:openid] is cleared
      #     * session[:openid]['authenticated'] is true
      #     * session[:openid]['identity'] is the actual identifier
      #     * session[:openid]['identifier'] is the pretty identifier
      #   * cancel: options[:login_quit] or session[:site_return]
      #     * session[:openid] is cleared
      #     * session[:openid]['authenticated'] is false
      #   * setup_needed: resubmits the authentication request. A flag is set
      #     for non-immediate handling.
      #     * session[:openid][:setup_needed] is set to true, which will
      #       prevent immediate style openid authentication.
      def finish(consumer, session, req)
        oid = consumer.complete(req.params, req.url)
        pp oid if $DEBUG
        req.env['rack.auth.openid.response'] = oid

        body = []
        goto = session.fetch :site_return, @realm

        case oid.status
        when ::OpenID::Consumer::FAILURE
          session.clear
          session['authenticated'] = false
          req.env['rack.errors'].puts oid.message

          goto = @options[:login_fail] if @option.key? :login_fail
          body << "Authentication unsuccessful.\n"
        when ::OpenID::Consumer::SUCCESS
          session.clear
          session['authenticated'] = true
          # Value for unique identification and such
          session['identity'] = oid.identity_url
          # Value for display and UI labels
          session['identifier'] = oid.display_identifier

          goto = @options[:login_good] if @option.key? :login_good
          body << "Authentication successful.\n"
        when ::OpenID::Consumer::CANCEL
          session.clear
          session['authenticated'] = false

          goto = @options[:login_fail] if @option.key? :login_fail
          body << "Authentication cancelled.\n"
        when ::OpenID::Consumer::SETUP_NEEDED
          session[:setup_needed] = true
          raise('Required values missing.') \
            unless o_id = session[:openid_param]

          goto = req.script_name+
            '?'+@options[:openid_param]+
            '='+o_id
          body << "Reauthentication required.\n"
        end
        body << oid.message if oid.message
        [ 303, {'Location'=>goto}, body]
      end
    end
  end
end
