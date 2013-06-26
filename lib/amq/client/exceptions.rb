# encoding: utf-8

module AMQ
  module Client

    #
    # Adapters
    #

    class TCPConnectionFailed < StandardError

      #
      # API
      #

      attr_reader :settings

      def initialize(settings)
        @settings = settings

        super("Could not establish TCP connection to #{@settings[:host]}:#{@settings[:port]}")
      end
    end

    # Base exception class for data consistency and framing errors.
    class InconsistentDataError < StandardError
    end

    # Raised by adapters when frame does not end with {final octet AMQ::Protocol::Frame::FINAL_OCTET}.
    # This suggest that there is a bug in adapter or AMQ broker implementation.
    #
    # @see http://bit.ly/amqp091spec AMQP 0.9.1 specification (Section 2.3)
    class NoFinalOctetError < InconsistentDataError
      def initialize
        super("Frame doesn't end with #{AMQ::Protocol::Frame::FINAL_OCTET} as it must, which means the size is miscalculated.")
      end
    end

    # Raised by adapters when actual frame payload size in bytes is not equal
    # to the size specified in that frame's header.
    # This suggest that there is a bug in adapter or AMQ broker implementation.
    #
    # @see http://bit.ly/amqp091spec AMQP 0.9.1 specification (Section 2.3)
    class BadLengthError < InconsistentDataError
      def initialize(expected_length, actual_length)
        super("Frame payload should be #{expected_length} long, but it's #{actual_length} long.")
      end
    end

    #
    # Client
    #

    class MissingHandlerError < StandardError
      def initialize(frame)
        super("No callback registered for #{frame.method_class}")
      end
    end

    class ConnectionClosedError < StandardError
      def initialize(frame)
        if frame.respond_to?(:method_class)
          super("Trying to send frame through a closed connection. Frame is #{frame.inspect}, method class is #{frame.method_class}")
        else
          super("Trying to send frame through a closed connection. Frame is #{frame.inspect}")
        end
      end # initialize
    end # class ConnectionClosedError

    module Logging
      # Raised when logger object passed to {AMQ::Client::Adapter.logger=} does not
      # provide API it supposed to provide.
      #
      # @see AMQ::Client::Adapter.logger=
      class IncompatibleLoggerError < StandardError
        def initialize(required_methods)
          super("Logger has to respond to the following methods: #{required_methods.inspect}")
        end
      end
    end # Logging


    class PossibleAuthenticationFailureError < StandardError

      #
      # API
      #

      def initialize(settings)
        super("AMQP broker closed TCP connection before authentication succeeded: this usually means authentication failure due to misconfiguration or that RabbitMQ version does not support AMQP 0.9.1. Please see http://bit.ly/amqp-gem-080-and-rabbitmq-versions and check your configuration. Settings are #{settings.inspect}.")
      end # initialize(settings)
    end # PossibleAuthenticationFailureError



    class UnknownExchangeTypeError < StandardError
      BUILTIN_TYPES = [:fanout, :direct, :topic, :headers].freeze

      def initialize(types, given)
        super("#{given.inspect} exchange type is unknown. Standard types are #{BUILTIN_TYPES.inspect}, custom exchange types must begin with x-, for example: x-recent-history")
      end
    end

  end # Client
end # AMQ
