# encoding: utf-8

module AMQP
  class Header

    #
    # API
    #

    # @api public
    def initialize(channel, method, header)
      @channel, @method, @header = channel, method, header
    end

    # Acknowledges the receipt of this message with the server.
    # @api public
    def ack(multiple = false)
      @channel.acknowledge(@method.delivery_tag, multiple)
    end

    # Reject this message.
    # * :requeue => true | false (default false)
    # @api public
    def reject(opts = {})
      @channel.reject(@method.delivery_tag, opts.fetch(:requeue, false))
    end

    def to_hash
      @header
    end # to_hash

    def respond_to_missing?(meth)
      (@header && args.empty? && blk.nil? && @header.has_key?(meth)) || @method.respond_to?(meth)
    end

    def method_missing(meth, *args, &blk)
      if @header && args.empty? && blk.nil? && @header.has_key?(meth)
        @header[meth]
      else
        @method.__send__(meth, *args, &blk)
      end
    end
  end # Header
end # AMQP
