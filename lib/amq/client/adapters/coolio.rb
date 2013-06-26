# encoding: utf-8

require "amq/client/async/adapters/coolio"

module AMQ
  module Client
    # backwards compatibility
    # @private
    CoolioClient = Async::CoolioClient
  end # Client
end # AMQ
