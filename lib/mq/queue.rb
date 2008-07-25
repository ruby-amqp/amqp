class MQ
  class Queue
    include AMQP
    
    def initialize mq, name, opts = {}
      @mq = mq
      @mq.queues[@name = name] ||= self
      @mq.callback{
        @mq.send Protocol::Queue::Declare.new({ :queue => name,
                                                :nowait => true }.merge(opts))
      }
    end
    attr_reader :name

    def bind exchange, opts = {}
      @mq.callback{
        @mq.send Protocol::Queue::Bind.new({ :queue => name,
                                             :exchange => exchange.respond_to?(:name) ? exchange.name : exchange,
                                             :routing_key => opts.delete(:key),
                                             :nowait => true }.merge(opts))
      }
      self
    end
    
    def subscribe opts = {}, &blk
      @on_msg = blk
      @mq.callback{
        @mq.send Protocol::Basic::Consume.new({ :queue => name,
                                                :consumer_tag => name,
                                                :no_ack => true,
                                                :nowait => true }.merge(opts))
      }
      self
    end

    def publish data, opts = {}
      exchange.publish(data, opts)
    end

    def receive headers, body
      if @on_msg
        @on_msg.call *(@on_msg.arity == 1 ? [body] : [headers, body])
      end
    end
  
    private
    
    def exchange
      @exchange ||= Exchange.new(@mq, :direct, '', :key => name)
    end
  end
end