module Thin
  module Backends
    class NTLMTcpServer < TcpServer
      def initialize(host, port, options)
        super(host, port)
      end

      def connect
        @signature = EventMachine.start_server(@host, @port, NTLMConnection, &method(:initialize_connection))
      end
    end
  end
end
