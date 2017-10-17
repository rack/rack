require 'pstore'
require 'tmpdir'
require 'openssl'
require 'rack/request'
require 'rack/response'
require 'rack/session/abstract/id'

module Rack

  module Session

    # Rack::Session::File provides simple filed based session management.
    # By default, the session is stored in /tmp while cookie holds only
    # session id.
    #
    # When the :secret key is set (recommended), cookie data is checked
    # for data integrity. The :old_secret key is also accepted allowing
    # smooth secret rotation.
    #
    # Garbage collection is controlled via :gc_probability and :gc_maxlife.
    # Every call to write_session, garbage collector is called with probability
    # of :gc_probability. It scans :dir for sessions files and deletes ones
    # with mtime older than :gc_maxlife.
    #
    # Supported options for constructor are:
    #
    #   :dir            directory into which save sessions
    #   :prefix         session file prefix
    #   :key            under what cookie save the session_id
    #   :domain         domain should the session_id cookie is valid for
    #   :path           path the session_id cookie is valid for
    #   :expire_after   session_id cookie expires after this seconds
    #   :secret         secret to use for integrity check
    #   :old_secret     secret previously used, allowing smooth secret rotation
    #
    #   :gc_probability probability of gc to run, in interval [0; 1]
    #   :gc_maxlife     how old (in seconds) session files should be cleaned up
    #
    # Default values:
    #
    #   :dir            File.join(Dir.tmpdir(), 'file-rack')
    #   :prefix         'file-rack-session-'
    #   :key            rack.session
    #   :domain         nil
    #   :path           nil
    #   :expire_after   nil
    #   :secret         nil
    #   :old_secret     nil
    #   :gc_probability 0.01
    #   :gc_maxlife     1200
    #
    # Example:
    #
    #   use Rack::Session::File, dir: '/tmp',
    #                            prefix: 'session-',
    #
    #   All parameters are optional.
    class File < Abstract::Persisted

      SESSION_ID = 'session_id'.freeze

      def initialize(app, options = {})
        @secrets = options.values_at(:secret, :old_secret).compact
        @hmac = options.fetch(:hmac, OpenSSL::Digest::SHA1)

        @dir = options[:dir] || ::File.join(Dir.tmpdir(), 'file-rack')
        @prefix = options[:prefix] || 'file-rack-session-'
        FileUtils.mkdir_p @dir

        @gc_probability = options[:gc_probability] || 0.01
        @gc_maxlife = options[:gc_maxlife] || 1200

        warn <<~MSG unless secure?(options)
          SECURITY WARNING: No secret option provided to Rack::Session::Cookie.
          This poses a security threat. It is strongly recommended that you
          provide a secret to prevent exploits that may be possible from crafted
          cookies. This will not be supported in future versions of Rack, and
          future versions will even invalidate your existing user cookies.

          Called from: #{caller[0]}.
        MSG

        super(app, options.merge!(cookie_only: false))
      end

      private

      def find_session(req, sid)
        data = load_data(req)
        data = persistent_session_id(data)
        [data[SESSION_ID], data]
      end

      def write_session(req, session_id, session, options)
        if options[:renew]
          session[SESSION_ID] = generate_sid
        end

        store = PStore.new(path_for_sid(session_id))
        store.transaction { store[:session] = session }

        try_gc_run!

        if @secrets.first
          "#{session_id}--#{generate_hmac(session_id, @secrets.first)}"
        else
          session_id
        end
      end

      def delete_session(req, session_id, options)
        begin
          File.delete(path_for_sid(session_id))
        rescue => e
          warn "Cannot delete session #{session_id}: #{e}"
        end

        unless options[:drop]
          generate_sid
        else
          nil
        end
      end

      def load_data(req)
        sid = req.cookies[@key]
        if @secrets.size > 0 and sid
          sid, digest = sid.split('--', 2)
          sid = nil unless digest_match?(sid, digest)
        end
        if sid
          store = PStore.new(path_for_sid(sid), read_only: true)
          store.transaction { store[:session] }
        else
          {}
        end
      end
      def persistent_session_id(data, sid = nil)
        data ||= {}
        data[SESSION_ID] ||= sid
        unless data[SESSION_ID]
          begin
            data[SESSION_ID] = generate_sid
          end while ::File.exist? path_for_sid(data[SESSION_ID])
        end
        data
      end

      def path_for_sid(sid)
        ::File.join @dir, "#{@prefix}#{sid}"
      end

      def digest_match?(data, digest)
        return unless data && digest
        @secrets.any? do |secret|
          Rack::Utils.secure_compare(digest, generate_hmac(data, secret))
        end
      end

      def generate_hmac(data, secret)
        OpenSSL::HMAC.hexdigest(@hmac.new, secret, data)
      end

      def secure?(options)
        @secrets.size >= 1
      end

      def try_gc_run!
        return unless Random.rand < @gc_probability

        threshold = Time.now - @gc_maxlife
        Dir.chdir(@dir) do
          Dir.entries(@dir).each do |entry|
            next unless entry[/#{@prefix}/]
            begin
              ::File.delete(entry) if ::File.mtime(entry) < threshold
            rescue => e
              warn "Cannot delete session file #{entry}: #{e}"
            end
          end
        end
      end

    end

  end

end
