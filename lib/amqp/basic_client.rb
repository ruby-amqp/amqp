# encoding: utf-8

require "amq/client/adapters/event_machine"

module AMQP
  # AMQP client implementation based on amq-client library. Left here for API compatibility
  # with 0.7.x series.
  #
  # @note This class is not part of the public API and may be removed in the future without any warning.
  class BasicClient < AMQ::Client::EventMachineClient

    #
    # API
    #

    # @api plugin
    def connected?
      self.opened?
    end

    # @api plugin
    def reconnect(force = false)
      # TODO
      raise NotImplementedError.new
    end # reconnect(force = false)
  end
end