# encoding: utf-8

module AMQP
  class Header

    #
    # API
    #

    # @api public
    def initialize(channel, header)
      @channel = channel
      @header  = header
    end

    # Acknowledges the receipt of this message with the server.
    # @api public
    def ack
      # TODO
    end

    # Reject this message.
    # * :requeue => true | false (default false)
    # @api public
    def reject(opts = {})
      # TODO
    end

    def to_hash
      @header
    end # to_hash

    def method_missing(meth, *args, &blk)
      @header.__send__(meth, *args, &blk)
    end
  end # Header
end # AMQP
