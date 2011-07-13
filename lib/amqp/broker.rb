# encoding: utf-8

module AMQP
  # A utility class that makes inspection of broker capabilities easier.
  class Broker

    #
    # API
    #

    RABBITMQ_PRODUCT = "RabbitMQ".freeze

    # Broker information
    # @return [Hash]
    # @see Session#server_properties
    attr_reader :properties

    # @return [Hash] properties Broker information
    # @see Session#server_properties
    def initialize(properties)
      @properties = properties
    end # initialize(properties)

    # @group Product information

    # @return [Boolean] true if broker is RabbitMQ
    def rabbitmq?
      self.product == RABBITMQ_PRODUCT
    end # rabbitmq?

    # @return [String] Broker product information
    def product
      @product ||= @properties["product"]
    end # product

    # @return [String] Broker version
    def version
      @version ||= @properties["version"]
    end # version

    # @endgroup



    # @group Product capabilities

    # @return [Boolean]
    def supports_publisher_confirmations?
      @properties["capabilities"]["publisher_confirms"]
    end # supports_publisher_confirmations?

    # @return [Boolean]
    def supports_basic_nack?
      @properties["capabilities"]["basic.nack"]
    end # supports_basic_nack?

    # @return [Boolean]
    def supports_consumer_cancel_notifications?
      @properties["capabilities"]["consumer_cancel_notify"]
    end # supports_consumer_cancel_notifications?

    # @return [Boolean]
    def supports_exchange_to_exchange_bindings?
      @properties["capabilities"]["exchange_exchange_bindings"]
    end # supports_exchange_to_exchange_bindings?


    # @endgroup


  end # Broker
end # AMQP
