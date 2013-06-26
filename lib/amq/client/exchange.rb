# encoding: utf-8

require "amq/client/async/exchange"

module AMQ
  module Client
    # backwards compatibility
    # @private
    Exchange = Async::Exchange
  end # Client
end # AMQ
