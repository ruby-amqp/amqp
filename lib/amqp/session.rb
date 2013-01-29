# encoding: utf-8

require "amq/client/adapters/event_machine"
require "amqp/broker"

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

    # @group Connecting, reconnecting, disconnecting

    def initialize(*args, &block)
      super(*args, &block)

      @client_properties.merge!({
        :platform    => ::RUBY_DESCRIPTION,
        :product     => "AMQP gem",
        :information => "http://github.com/ruby-amqp/amqp",
        :version     => AMQP::VERSION
      })
    end # initialize(*args, &block)

    # @return [Boolean] true if this AMQP connection is currently open
    # @api plugin
    def connected?
      self.opened?
    end

    # @return [String] Broker hostname this connection uses
    # @api public
    def hostname
      @settings[:host]
    end
    alias host hostname

    # @return [String] Broker port this connection uses
    # @api public
    def port
      @settings[:port]
    end

    # @return [String] Broker endpoint in the form of HOST:PORT/VHOST
    # @api public
    def broker_endpoint
      "#{self.hostname}:#{self.port}/#{self.vhost}"
    end

    # @return [String] Username used by this connection
    # @api public
    def username
      @settings[:user]
    end # username
    alias user username


    # Reconnect to the broker using current connection settings.
    #
    # @param [Boolean] force Enforce immediate connection
    # @param [Fixnum] period If given, reconnection will be delayed by this period, in seconds.
    # @api public
    def reconnect(force = false, period = 2)
      # we do this to make sure this method shows up in our documentation
      # this method is too important to leave out and YARD currently does not
      # support cross-referencing to dependencies. MK.
      super(force, period)
    end # reconnect(force = false)

    # A version of #reconnect that allows connecting to different endpoints (hosts).
    # @see #reconnect
    # @api public
    def reconnect_to(connection_string_or_options = {}, period = 2)
      opts = case connection_string_or_options
             when String then
               AMQP::Client.parse_connection_uri(connection_string_or_options)
             when Hash then
               connection_string_or_options
             else
               Hash.new
             end

      super(opts, period)
    end # reconnect_to(connection_string_or_options = {})


    # Properly close connection with AMQ broker, as described in
    # section 2.2.4 of the {http://files.travis-ci.org/docs/amqp/0.9.1/AMQP091Specification.pdf AMQP 0.9.1 specification}.
    #
    # @api  plugin
    # @see  #close_connection
    def disconnect(reply_code = 200, reply_text = "Goodbye", &block)
      # defined here to make this method appear in YARD documentation. MK.
      super(reply_code, reply_text, &block)
    end
    alias close disconnect

    # @endgroup



    # @group Broker information

    # Server properties (product information, platform, et cetera)
    #
    # @return [Hash]
    # @see http://files.travis-ci.org/docs/amqp/0.9.1/AMQP091Reference.pdf AMQP 0.9.1 protocol documentation (Section 1.4.2.1.3)
    attr_reader :server_properties

    # Server capabilities (usually used to detect AMQP 0.9.1 extensions like basic.nack, publisher
    # confirms and so on)
    #
    # @return [Hash]
    # @see http://files.travis-ci.org/docs/amqp/0.9.1/AMQP091Reference.pdf AMQP 0.9.1 protocol documentation (Section 1.4.2.1.3)
    attr_reader :server_capabilities

    # Locales server supports
    #
    # @see http://files.travis-ci.org/docs/amqp/0.9.1/AMQP091Reference.pdf AMQP 0.9.1 protocol documentation (Section 1.4.2.1.3)
    attr_reader :server_locales

    # @return [AMQP::Broker] Broker this connection is established with
    def broker
      @broker ||= AMQP::Broker.new(@server_properties)
    end # broker

    # @endgroup



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


    # @group Error Handling and Recovery

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

    # Defines a callback that will be run when TCP connection to AMQP broker is lost (interrupted).
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

    # Defines a callback that will be executed after TCP connection is interrupted (typically because of a network failure).
    # Only one callback can be defined (the one defined last replaces previously added ones).
    #
    # @api public
    def on_connection_interruption(&block)
      super(&block)
    end # on_connection_interruption(&block)
    alias after_connection_interruption on_connection_interruption


    # @private
    # @api plugin
    def handle_connection_interruption
      super
    end # handle_connection_interruption


    # Defines a callback that will be executed when connection is closed after
    # connection-level exception. Only one callback can be defined (the one defined last
    # replaces previously added ones).
    #
    # @api public
    def on_error(&block)
      super(&block)
    end


    # Defines a callback that will be executed after TCP connection has recovered after a network failure
    # but before AMQP connection is re-opened.
    # Only one callback can be defined (the one defined last replaces previously added ones).
    #
    # @api public
    def before_recovery(&block)
      super(&block)
    end # before_recovery(&block)


    # Defines a callback that will be executed after AMQP connection has recovered after a network failure..
    # Only one callback can be defined (the one defined last replaces previously added ones).
    #
    # @api public
    def on_recovery(&block)
      super(&block)
    end # on_recovery(&block)
    alias after_recovery on_recovery


    # @return [Boolean] whether connection is in the automatic recovery mode
    # @api public
    def auto_recovering?
      super
    end # auto_recovering?
    alias auto_recovery? auto_recovering?


    # Performs recovery of channels that are in the automatic recovery mode.
    #
    # @see Channel#auto_recover
    # @see Queue#auto_recover
    # @see Exchange#auto_recover
    # @api plugin
    def auto_recover
      super
    end # auto_recover

    # @endgroup



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
