require "amq/client/adapters/event_machine"

module AMQP
  class BasicClient < AMQ::Client::EventMachineClient

    #
    # API
    #

    # @api public
    def connected?
      self.opened?
    end

    # @api public
    def reconnect(force = false)
      # TODO
      raise NotImplementedError.new
    end # reconnect(force = false)
  end
end