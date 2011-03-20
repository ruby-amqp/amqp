# encoding: utf-8

module AMQP
  class Header

    #
    # API
    #

    # @api public
    def initialize(channel, header, delivery_tag = nil)
      @channel      = channel
      @header       = header
      @delivery_tag = delivery_tag
    end

    # Acknowledges the receipt of this message with the server.
    # @api public
    def ack(multiple = false)
      @channel.acknowledge(@delivery_tag, multiple)
    end

    # Reject this message.
    # * :requeue => true | false (default false)
    # @api public
    def reject(opts = {})
      @channel.reject(@delivery_tag, opts.fetch(:requeue, false))
    end

    def to_hash
      @header
    end # to_hash

    def method_missing(meth, *args, &blk)
      @header.__send__(meth, *args, &blk)
    end
  end # Header
end # AMQP
