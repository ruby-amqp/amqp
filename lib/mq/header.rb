# encoding: utf-8

class MQ
  class Header
    include AMQP

    def initialize(mq, header_obj)
      @mq = mq
      @header = header_obj
    end

    # Acknowledges the receipt of this message with the server.
    def ack
      @mq.callback {
        @mq.send Protocol::Basic::Ack.new(:delivery_tag => properties[:delivery_tag])
      }
    end

    # Reject this message (XXX currently unimplemented in rabbitmq)
    # * :requeue => true | false (default false)
    def reject(opts = {})
      if @mq.broker.server_properties[:product] == "RabbitMQ"
        raise NotImplementedError.new("RabbitMQ doesn't implement the Basic.Reject method\nSee http://lists.rabbitmq.com/pipermail/rabbitmq-discuss/2009-February/002853.html")
      else
        @mq.callback {
          @mq.send Protocol::Basic::Reject.new(opts.merge(:delivery_tag => properties[:delivery_tag]))
        }
      end
    end

    def method_missing(meth, *args, &blk)
      @header.send meth, *args, &blk
    end

    def inspect
      @header.inspect
    end
  end
end
