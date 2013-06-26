# encoding: utf-8

require "amq/client/async/entity"

module AMQ
  module Client
    # backwards compatibility
    # @private    
    RegisterEntityMixin    = Async::RegisterEntityMixin
    ProtocolMethodHandlers = Async::ProtocolMethodHandlers
    Entity                 = Async::Entity
  end # Client
end # AMQ
