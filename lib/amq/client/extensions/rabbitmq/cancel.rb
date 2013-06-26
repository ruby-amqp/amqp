# encoding: utf-8

require "amq/client/async/extensions/rabbitmq/cancel"

# Basic.Cancel
module AMQ
  module Client
    # backwards compatibility
    # @private
    Extensions = Async::Extensions unless defined?(Extensions)

    module Settings
      CLIENT_PROPERTIES[:capabilities] ||= {}
      CLIENT_PROPERTIES[:capabilities][:consumer_cancel_notify] = true
    end
  end # Client
end # AMQ
