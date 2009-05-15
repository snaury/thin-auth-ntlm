require 'thin/ntlm/connection'
require 'thin/backends/tcp_server'

module Thin
  module Backends
    class TcpServer
      def connect
        @signature = EventMachine.start_server(@host, @port, NTLMConnection, &method(:initialize_connection))
      end
    end
  end
end
