# encoding: utf-8

require "amq/client/async/channel"

module AMQ
  module Client
    # backwards compatibility
    # @private
    Channel = Async::Channel
  end # Client
end # AMQ
