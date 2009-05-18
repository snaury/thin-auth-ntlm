require 'thin'

module Thin
  autoload :NTLMConnection, 'thin/ntlm/connection'

  module Backends
    autoload :NTLMTcpServer, 'thin/ntlm/backends/tcp_server'
  end
end
