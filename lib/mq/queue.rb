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

    def unbind exchange, opts = {}
      @mq.callback{
        @mq.send Protocol::Queue::Unbind.new({ :queue => name,
                                               :exchange => exchange.respond_to?(:name) ? exchange.name : exchange,
                                               :routing_key => opts.delete(:key),
                                               :nowait => true }.merge(opts))
      }
      self
    end

    def delete opts = {}
      @mq.callback{
        @mq.send Protocol::Queue::Delete.new({ :queue => name,
                                               :nowait => true }.merge(opts))
      }
      @mq.queues.delete @name
      nil
    end
    
    def subscribe opts = {}, &blk
      @consumer_tag = "#{name}-#{Kernel.rand(999_999_999_999)}"
      @mq.consumers[@consumer_tag] = self

      @on_msg = blk
      @mq.callback{
        @mq.send Protocol::Basic::Consume.new({ :queue => name,
                                                :consumer_tag => @consumer_tag,
                                                :no_ack => true,
                                                :nowait => true }.merge(opts))
      }
      self
    end

    def unsubscribe opts = {}, &blk
      @on_cancel = blk
      @mq.callback{
        @mq.send Protocol::Basic::Cancel.new({ :consumer_tag => @consumer_tag }.merge(opts))
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

    def cancelled
      @on_cancel.call if @on_cancel
      @on_cancel = @on_msg = nil
      @mq.consumers.delete @consumer_tag
      @consumer_tag = nil
    end
  
    private
    
    def exchange
      @exchange ||= Exchange.new(@mq, :direct, '', :key => name)
    end
  end
end