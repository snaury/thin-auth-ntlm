require 'thin/connection'
require 'win32/sspi/server'

module Thin
  class NTLMConnection < Connection
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

    def unbind
      ntlm_cleanup
    ensure
      super
    end

    def process
      # check if browser wants to reauthenticate
      if @authenticated_as && http_authorization
        @authenticated_as = nil
      end
      # require authentication
      unless @authenticated_as
        unless @authentication_stage
          @post_ntlm_can_persist = @can_persist
          @authentication_stage = 1
        end
        result = ntlm_process
        return post_process(result) unless @authenticated_as
      end

      @request.env[REMOTE_USER] = @authenticated_as
      @can_persist = @post_ntlm_can_persist
      return super
    end

    def http_authorization
      auth = @request.env[HTTP_AUTHORIZATION]
      if auth
        auth = auth.strip
        auth = nil if auth.empty?
      end
      auth
    end

    def ntlm_acquire(package = 'NTLM')
      ntlm_cleanup
      @ntlm = Win32::SSPI::NegotiateServer.new(package)
      @ntlm.acquire_credentials_handle
      @ntlm
    end

    def ntlm_cleanup
      if @ntlm
        @ntlm.cleanup rescue nil
        @ntlm = nil
      end
      nil
    end

    def ntlm_token
      auth = http_authorization
      return [nil, nil] unless auth && auth.match(/\A(#{NTLM_ALLOWED_PACKAGE}) (.*)\Z/)
      [$1, Base64.decode64($2.strip)]
    end

    def ntlm_process
      case @authentication_stage
      when 1 # we are waiting for type1 message
        package, t1 = ntlm_token
        return ntlm_request_auth(NTLM_REQUEST_PACKAGE, false) if t1.nil?
        return ntlm_request_auth unless request.persistent?
        begin
          ntlm_acquire(package)
          t2 = @ntlm.accept_security_context(t1)
        rescue
          return ntlm_request_auth
        end
        ntlm_request_auth("#{package} #{t2}", false, 2)
      when 2 # we are waiting for type3 message
        package, t3 = ntlm_token
        return ntlm_request_auth(NTLM_REQUEST_PACKAGE, false) if t3.nil?
        return ntlm_request_auth unless package == @ntlm.package
        return ntlm_request_auth unless request.persistent?
        begin
          t2 = @ntlm.accept_security_context(t3)
          @authenticated_as = @ntlm.get_username_from_context
          @authentication_stage = 1 # in case IE8 wants to reauthenticate
        rescue
          return ntlm_request_auth
        end
        return ntlm_request_auth unless @authenticated_as
        ntlm_cleanup
      else
        raise "Invalid value for @authentication_stage=#{@authentication_stage} detected"
      end
    rescue Exception
      handle_error
      terminate_request
      nil
    end

    def ntlm_request_auth(auth = nil, finished = true, next_stage = 1)
      @authentication_stage = next_stage
      @can_persist = !finished
      head = {}
      head[WWW_AUTHENTICATE] = auth if auth
      head[CONTENT_TYPE] = CONTENT_TYPE_AUTH
      return [401, head, [AUTHORIZATION_MESSAGE]]
    end
  end
end
