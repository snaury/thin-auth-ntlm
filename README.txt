= NTLM Authentication for Thin

Allows you to force NTLM authentication on Thin TCP servers.

= Using thin-auth-ntlm

If you want to force NTLM authentication on all tcp servers, just do:

  require 'thin/ntlm/backends/tcp_server'

However, since this is intended for use with rails, there's another way.

Add this in your config/environment.rb:

  config.gem 'thin-auth-ntlm', :lib => 'thin/ntlm/backends/tcp_server'

Or create config/preinitializer.rb:

  module Rails
    class Boot
      old_run = self.instance_method(:run)
      define_method(:run) do
        old_run.bind(self).call
        require 'thin'
        ::Rack::Handler.autoload :Thin, 'rack/handler/thin_ntlm'
      end
    end
  end

This way when rails tries to use Rack::Handler::Thin the TCPServer patch
will be automatically installed and you will be using NTLMConnection.
