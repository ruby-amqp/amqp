# encoding: utf-8

require "amq/client/logging"
require "amq/client/settings"

require "amq/client/async/queue"
require "amq/client/async/exchange"
require "amq/client/async/channel"
require "amq/client/async/adapter"

module AMQ
  # For overview of AMQP client adapters API, see {AMQ::Client::Adapter}
  module Client

    # backwards compatibility
    # @private
    Adapter = Async::Adapter
  end # Client
end # AMQ
