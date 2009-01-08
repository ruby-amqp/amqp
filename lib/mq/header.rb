class MQ
  class Header
    include AMQP

    def initialize(mq, header_obj)
      @mq = mq
      @header = header_obj
    end

    # Acknowledges the receipt of this message with the server.
    def ack
      @mq.callback do
        @mq.send Protocol::Basic::Ack.new(:delivery_tag => properties[:delivery_tag])
      end
    end

    def method_missing meth, *args, &blk
      @header.send meth, *args, &blk
    end

    def inspect
      @header.inspect
    end
  end
end
