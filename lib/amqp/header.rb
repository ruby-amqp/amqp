# encoding: utf-8

module AMQP
  # We keep this class around for sake of API compatibility with 0.7.x series.
  #
  # @note This class is not part of the public API and may be removed in the future without any warning.
  class Header

    #
    # API
    #

    # @return [AMQP::Channel]
    attr_reader :channel
    # AMQP method frame this header is associated with. Carries additional information that varies between AMQP methods.
    # @return [AMQ::Protocol::Method]
    attr_reader :method
    # AMQP message header as a hash
    # @return [Hash]
    attr_reader :header

    # @api public
    def initialize(channel, method, header)
      @channel, @method, @header = channel, method, header
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
      @header
    end # to_hash

    def respond_to_missing?(meth, _)
      (@header && args.empty? && blk.nil? && @header.has_key?(meth)) || @method.respond_to?(meth)
    end

    # Returns AMQP message attributes.
    # @api public
    def method_missing(meth, *args, &blk)
      if @header && args.empty? && blk.nil? && @header.has_key?(meth)
        @header[meth]
      else
        @method.__send__(meth, *args, &blk)
      end
    end
  end # Header
end # AMQP
