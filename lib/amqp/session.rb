# encoding: utf-8

require "amq/client/adapters/event_machine"

module AMQP
  class Session < AMQ::Client::EventMachineClient

    #
    # API
    #

    # @api plugin
    def connected?
      self.opened?
    end

    # Reconnect to the broker using current connection settings.
    #
    # @param [Boolean] force Enforce immediate connection
    # @param [Fixnum] period If given, reconnection will be delayed by this period, in seconds.
    # @api plugin
    def reconnect(force = false, period = 2)
      # we do this to make sure this method shows up in our documentation
      # this method is too important to leave out and YARD currently does not
      # support cross-referencing to dependencies. MK.
      super(force, period)
    end # reconnect(force = false)




    #
    # Implementation
    #

    # Overrides TCP connection failure exception to one that inherits from AMQP::Error
    # and thus is backwards compatible.
    #
    # @private
    # @api plugin
    # @return [Class] AMQP::TCPConnectionFailed
    def self.tcp_connection_failure_exception_class
      @tcp_connection_failure_exception_class ||= AMQP::TCPConnectionFailed
    end # self.tcp_connection_failure_exception_class
  end # Session
end # AMQP
