# encoding: utf-8

require "amq/client/async/adapters/eventmachine"

module AMQ
  module Client
    # backwards compatibility
    # @private
    EventMachineClient = Async::EventMachineClient
  end # Client
end # AMQ
