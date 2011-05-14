# encoding: utf-8

require "amq/client/adapters/event_machine"

module AMQP
  # AMQP session represents connection to the broker. Session objects let you define callbacks for
  # various TCP connection lifecycle events, for instance:
  #
  # * Connection is established
  # * Connection has failed
  # * Authentication has failed
  # * Connection is lost (there is a network failure)
  # * AMQP connection is opened
  # * AMQP connection parameters (tuning) are negotiated and accepted by the broker
  # * AMQP connection is properly closed
  #
  # h2. Key methods
  #
  # * {Session#on_connection}
  # * {Session#on_open}
  # * {Session#on_disconnection}
  # * {Session#on_possible_authentication_failure}
  # * {Session#on_tcp_connection_failure}
  # * {Session#on_tcp_connection_loss}
  # * {Session#reconnect}
  # * {Session#connected?}
  #
  #
  # @api public
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


    # Defines a callback that will be executed when AMQP connection is considered open:
    # after client and broker has agreed on max channel identifier and maximum allowed frame
    # size and authentication succeeds. You can define more than one callback.
    #
    # @see #on_closed
    # @api public
    def on_open(&block)
      # defined here to make this method appear in YARD documentation. MK.
      super(&block)
    end # on_open(&block)

    # Defines a callback that will be run when broker confirms connection termination
    # (client receives connection.close-ok). You can define more than one callback.
    #
    # @see #on_closed
    # @api public
    def on_closed(&block)
      # defined here to make this method appear in YARD documentation. MK.
      super(&block)
    end # on_closed(&block)

    # Defines a callback that will be run when initial TCP connection fails.
    # You can define only one callback.
    #
    # @api public
    def on_tcp_connection_failure(&block)
      # defined here to make this method appear in YARD documentation. MK.
      super(&block)
    end

    # Defines a callback that will be run when initial TCP connection fails.
    # You can define only one callback.
    #
    # @api public
    def on_tcp_connection_loss(&block)
      # defined here to make this method appear in YARD documentation. MK.
      super(&block)
    end

    # Defines a callback that will be run when TCP connection is closed before authentication
    # finishes. Usually this means authentication failure. You can define only one callback.
    #
    # @api public
    def on_possible_authentication_failure(&block)
      # defined here to make this method appear in YARD documentation. MK.
      super(&block)
    end


    # Properly close connection with AMQ broker, as described in
    # section 2.2.4 of the {http://bit.ly/hw2ELX AMQP 0.9.1 specification}.
    #
    # @api  plugin
    # @see  #close_connection
    def disconnect(reply_code = 200, reply_text = "Goodbye", &block)
      # defined here to make this method appear in YARD documentation. MK.
      super(reply_code, reply_text, &block)
    end
    alias close disconnect



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


    # Overrides authentication failure exception to one that inherits from AMQP::Error
    # and thus is backwards compatible.
    #
    # @private
    # @api plugin
    # @return [Class] AMQP::PossibleAuthenticationFailureError
    def self.authentication_failure_exception_class
      @authentication_failure_exception_class ||= AMQP::PossibleAuthenticationFailureError
    end # self.authentication_failure_exception_class
  end # Session
end # AMQP
