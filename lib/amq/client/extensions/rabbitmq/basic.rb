# encoding: utf-8

require "amq/client/async/extensions/rabbitmq/basic"

# Basic.Nack
module AMQ
  module Client
    # backwards compatibility
    # @private
    Extensions = Async::Extensions unless defined?(Extensions)
  end # Client
end # AMQ
