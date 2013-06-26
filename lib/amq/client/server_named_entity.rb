# encoding: utf-8

module AMQ
  module Client
    # Common behavior of AMQ entities that can be either client or server-named, for example, exchanges and queues.
    module ServerNamedEntity

      # @return [Boolean] true if this entity is anonymous (server-named)
      def server_named?
        @server_named || @name.nil? || @name.empty?
      end
      # backwards compabitility. MK.
      alias anonymous? server_named?
    end # ServerNamedEntity
  end # Client
end # AMQ
