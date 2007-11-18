# AUTHOR: blink <blinketje@gmail.com>; blink#ruby-lang@irc.freenode.net

require 'rack/auth/abstract/handler'
require 'openid'

module Rack
  module Auth
    # Rack::Auth::OpenID provides a simple method for permitting openid
    # based logins. It requires the ruby-openid lib from janrain to operate,
    # as well as some method of session management of a Hash type.
    #
    # NOTE: Due to the amount of data that ruby-openid stores in the session,
    # Rack::Session::Cookie may fault.
    #
    # A hash of data is stored in the session hash at the key of :openid.
    # The fully canonicalized identity url is stored within at 'identity'.
    # Extension data from 'openid.sreg.nickname' would be stored as
    # { 'nickname' => value }.
    #
    # NOTE: To my knowledge there is no collision at this point from storage
    # of this manner, if there is please let me know so I may adjust this app
    # to cope.
    class OpenID < AbstractHandler
      # Required for ruby-openid
      OIDStore = ::OpenID::MemoryStore.new

      # A Hash of options is taken as it's single initializing argument. String
      # keys are taken to be openid protocol extension namespaces. For example:
      #   'sreg' => { 'required' => 'nickname' }
      # If you wish, you may pass a block to OpenID.new, which will be called just
      # before a response is returned. The passed arguments are the OpenID app's
      # normal status, header, and body, as well as the openid object generated
      # during handling. The returned value should be normal Rack
      # [status,header,body].
      #
      # Other keys are taken as options for Rack::Auth::OpenID, normally Symbols.
      # Only :return is required. :trust is highly recommended to be set.
      #
      # * :return defines the url to return to after the client authenticates
      #   with the openid service provider. Should point to where this app is
      #   mounted. (ex: 'http://mysite.com/openid')
      # * :trust defines the url identifying the site they are actually logging
      #   into. (ex: 'http://mysite.com/')
      # * :session_key defines the key to the session hash in the env.
      #   (by default it uses 'rack.session')
      def initialize(options={}, &block)
        raise ArgumentError, 'No return url provided.'  unless options[:return]
        warn  'No trust url provided.'  unless options[:trust]
        options[:trust] ||= options[:return]

        @followup = block || proc{|r|r[0..2]}

        @options  = {
          :session_key => 'rack.session'
        }.merge(options)
      end

      def call(env)
        request = Rack::Request.new env
        return no_session unless session = request.env[@options[:session_key]]
        resp = if request.GET['openid.mode']
                 finish session, request.GET
               elsif request.GET['openid_url']
                 check session, request.GET['openid_url'], request
               else
                 bad_request
               end
        @followup.call(resp)
      end

      def check(session, oid_url, request=nil)
        consumer = ::OpenID::Consumer.new session, OIDStore
        oid = consumer.begin oid_url
        return auth_fail unless oid.status == ::OpenID::SUCCESS
        @options.each do |ns,s|
          next unless ns.is_a? String
          s.each {|k,v| oid.add_extension_arg(ns, k, v) }
        end
        r_url = @options.fetch :return do |k| request.url end
        t_url = @options.fetch :trust
        return [303, {'Location'=>oid.redirect_url( t_url, r_url )}, [], oid]
      end

      def finish(session, params)
        consumer = ::OpenID::Consumer.new session, OIDStore
        oid = consumer.complete params
        return bad_login unless oid.status == ::OpenID::SUCCESS
        session[:openid] = {'identity' => oid.identity_url}
        @options.each do |ns,s|
          next unless ns.is_a? String
          oid.extension_response(ns).each{|k,v| session[k]=v }
        end
        return [303, {'Location'=>@options[:trust]}, [], oid]
      end

      def no_session
        @options.
          fetch :no_session, [500,{'Content-Type'=>'text/plain'},'No session available.']
      end
      def auth_fail
        @options.
          fetch :auth_fail, [500, {'Content-Type'=>'text/plain'},'Foreign server failure.']
      end
      def bad_login
        @options.
          fetch :bad_login, [401, {'Content-Type'=>'text/plain'},'Identification has failed.']
      end
    end
  end
end
