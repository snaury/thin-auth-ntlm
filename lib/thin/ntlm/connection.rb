require 'weakref'
require 'win32/sspi/server'

module Thin
  class NTLMWrapper
    AUTHORIZATION_MESSAGE = <<END
<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">
<html><head>
<title>401 NTLM Authorization Required</title>
</head><body>
<h1>NTLM Authorization Required</h1>
<p>This server could not verify that you
are authorized to access the document
requested.  Either you supplied the wrong
credentials (e.g., bad password), or your
browser doesn't understand how to supply
the credentials required.</p>
</body></html>
END
    REMOTE_USER = 'REMOTE_USER'.freeze
    HTTP_AUTHORIZATION = 'HTTP_AUTHORIZATION'.freeze
    WWW_AUTHENTICATE = 'WWW-Authenticate'.freeze
    CONTENT_TYPE = 'Content-Type'.freeze
    CONTENT_TYPE_AUTH = 'text/html; charset=iso-8859-1'.freeze
    NTLM_REQUEST_PACKAGE = 'NTLM'.freeze
    NTLM_ALLOWED_PACKAGE = 'NTLM|Negotiate'.freeze

    def initialize(app, connection)
      @app = app
      @connection = WeakRef.new(connection)
    end

    def deferred?(env)
      @app.respond_to?(:deferred?) && @app.deferred?(env)
    end

    def persistent?
      @connection.request.persistent?
    end

    def can_persist!
      @connection.can_persist!
    end

    def ntlm_start
      @connection.ntlm_start
    end

    def ntlm_stop
      @connection.ntlm_stop
    end

    def call(env)
      # check if browser wants to reauthenticate
      if @authenticated_as && http_authorization(env)
        @authenticated_as = nil
      end

      # require authentication
      unless @authenticated_as
        ntlm_start
        @authentication_stage ||= 1
        result = process(env)
        return result unless @authenticated_as
        ntlm_stop
      end

      # pass thru
      env[REMOTE_USER] = @authenticated_as
      @app.call(env)
    end

    # Returns stripped HTTP-Authorization header, nil if none or empty
    def http_authorization(env)
      auth = env[HTTP_AUTHORIZATION]
      if auth
        auth = auth.strip
        auth = nil if auth.empty?
      end
      auth
    end

    # Returns token type and value from HTTP-Authorization header
    def token(env)
      auth = http_authorization(env)
      return [nil, nil] unless auth && auth.match(/\A(#{NTLM_ALLOWED_PACKAGE}) (.*)\Z/)
      [$1, Base64.decode64($2.strip)]
    end

    # Acquires new OS credentials handle
    def acquire(package = 'NTLM')
      cleanup
      @ntlm = Win32::SSPI::NegotiateServer.new(package)
      @ntlm.acquire_credentials_handle
      @ntlm
    end

    # Frees credentials handle, if acquired
    def cleanup
      if @ntlm
        @ntlm.cleanup rescue nil
        @ntlm = nil
      end
      nil
    end

    # Processes current authentication stage
    # Returns rack response if authentication is incomplete
    # Sets @authenticated_as to username if authentication successful
    def process(env)
      case @authentication_stage
      when 1 # we are waiting for type1 message
        package, t1 = token(env)
        return request_auth(NTLM_REQUEST_PACKAGE, false) if t1.nil?
        return request_auth unless persistent?
        begin
          acquire(package)
          t2 = @ntlm.accept_security_context(t1)
        rescue
          return request_auth
        end
        request_auth("#{package} #{t2}", false, 2)
      when 2 # we are waiting for type3 message
        package, t3 = token(env)
        return request_auth(NTLM_REQUEST_PACKAGE, false) if t3.nil?
        return request_auth unless package == @ntlm.package
        return request_auth unless persistent?
        begin
          t2 = @ntlm.accept_security_context(t3)
          @authenticated_as = @ntlm.get_username_from_context
          @authentication_stage = nil # in case IE wants to reauthenticate
        rescue
          return request_auth
        end
        return request_auth unless @authenticated_as
        cleanup
      else
        raise "Invalid value for @authentication_stage=#{@authentication_stage} detected"
      end
    end

    # Returns response with authentication request to the client
    def request_auth(auth = nil, finished = true, next_stage = 1)
      @authentication_stage = next_stage
      can_persist! unless finished
      head = {}
      head[WWW_AUTHENTICATE] = auth if auth
      head[CONTENT_TYPE] = CONTENT_TYPE_AUTH
      [401, head, [AUTHORIZATION_MESSAGE]]
    end
  end

  class NTLMConnection < Connection
    def app=(app)
      super NTLMWrapper.new(app, self)
    end

    def unbind
      @app.cleanup if @app && @app.respond_to?(:cleanup)
    ensure
      super
    end

    # Saves original can_persist? value (NTLM will force persistence)
    def ntlm_start
      unless @ntlm_in_progress
        @ntlm_saved_can_persist = @can_persist
        @ntlm_in_progress = true
      end
    end

    # Restores previous can_persist? value
    def ntlm_stop
      if @ntlm_in_progress
        @can_persist = @ntlm_saved_can_persist
        @ntlm_in_progress = false
      end
    end
  end
end
