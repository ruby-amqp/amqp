# encoding: utf-8

module AMQP
  # Message metadata (aka envelope).
  class Header

    #
    # API
    #

    # @api public
    # @return [AMQP::Channel]
    attr_reader :channel

    # AMQP method frame this header is associated with.
    # Carries additional information that varies between AMQP methods.
    #
    # @api public
    # @return [AMQ::Protocol::Method]
    attr_reader :method

    # AMQP message attributes
    # @return [Hash]
    attr_reader :attributes

    # @api public
    def initialize(channel, method, attributes)
      @channel, @method, @attributes = channel, method, attributes
    end

    # Acknowledges the receipt of this message with the server.
    # @param [Boolean] multiple Whether or not to acknowledge multiple messages
    # @api public
    def ack(multiple = false)
      @channel.acknowledge(@method.delivery_tag, multiple)
    end

    # Reject this message.
    # @option opts [Hash] :requeue (false) Whether message should be requeued.
    # @api public
    def reject(opts = {})
      @channel.reject(@method.delivery_tag, opts.fetch(:requeue, false))
    end

    # @return [Hash] AMQP message header w/o method-specific information.
    # @api public
    def to_hash
      @attributes
    end # to_hash

    def delivery_tag
      @method.delivery_tag
    end # delivery_tag

    def consumer_tag
      @method.consumer_tag
    end # consumer_tag

    def redelivered
      @method.redelivered
    end # redelivered

    def redelivered?
      @method.redelivered
    end # redelivered?

    def exchange
      @method.exchange
    end # exchange

    # @deprecated
    def header
      @attributes
    end # header

    def headers
      @attributes[:headers]
    end # headers

    def delivery_mode
      @attributes[:delivery_mode]
    end # delivery_mode

    def content_type
      @attributes[:content_type]
    end # content_type

    def timestamp
      @attributes[:timestamp]
    end # timestamp

    def type
      @attributes[:type]
    end # type

    def priority
      @attributes[:priority]
    end # priority

    def reply_to
      @attributes[:reply_to]
    end # reply_to

    def correlation_id
      @attributes[:correlation_id]
    end # correlation_id

    def message_id
      @attributes[:message_id]
    end # message_id


    # Returns AMQP message attributes.
    # @api public
    def method_missing(meth, *args, &blk)
      if @attributes && args.empty? && blk.nil? && @attributes.has_key?(meth)
        @attributes[meth]
      else
        @method.__send__(meth, *args, &blk)
      end
    end
  end # Header
end # AMQP
