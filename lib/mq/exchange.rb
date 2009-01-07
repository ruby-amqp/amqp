class MQ
  # An Exchange acts as an ingress point for all published messages. An
  # exchange may also be described as a router or a matcher. Every
  # published message is received by an exchange which, depending on its
  # type (described below), determines how to deliver the message.
  #
  # It determines the next delivery hop by examining the bindings associated
  # with the exchange.
  #
  # There are three (3) supported Exchange types: direct, fanout and topic.
  #
  # As part of the standard, the server _must_ predeclare the direct exchange
  # 'amq.direct' and the fanout exchange 'amq.fanout' (all exchange names 
  # starting with 'amq.' are reserved). Attempts to declare an exchange using
  # 'amq.' as the name will raise an MQ:Error and fail. In practice these
  # default exchanges are never used directly by client code.
  #
  # These predececlared exchanges are used when the client code declares
  # an exchange without a name. In these cases the library will use
  # the default exchange for publishing the messages.
  #
  class Exchange
    include AMQP

    def initialize mq, type, name, opts = {}
      @mq = mq
      @type, @name = type, name
      @mq.exchanges[@name = name] ||= self
      @key = opts[:key]
      
      @mq.callback{
        @mq.send Protocol::Exchange::Declare.new({ :exchange => name,
                                                   :type => type,
                                                   :nowait => true }.merge(opts))
      } unless name == "amq.#{type}" or name == ''
    end
    attr_reader :name, :type, :key

    # This method publishes a staged file message to a specific exchange.
    # The file message will be routed to queues as defined by the exchange
    # configuration and distributed to any active consumers when the
    # transaction, if any, is committed.
    #
    #  exchange = MQ.direct('name', :key => 'foo.bar')
    #  exchange.publish("some data")
    #
    # The method takes several hash key options which modify the behavior or 
    # lifecycle of the message.
    #
    # * :routing_key => 'string'
    #
    # Specifies the routing key for the message.  The routing key is
    # used for routing messages depending on the exchange configuration.
    #
    # * :mandatory => true | false (default false)
    #
    # This flag tells the server how to react if the message cannot be
    # routed to a queue.  If this flag is set, the server will return an
    # unroutable message with a Return method.  If this flag is zero, the
    # server silently drops the message.
    #
    # * :immediate => true | false (default false)
    #
    # This flag tells the server how to react if the message cannot be
    # routed to a queue consumer immediately.  If this flag is set, the
    # server will return an undeliverable message with a Return method.
    # If this flag is zero, the server will queue the message, but with
    # no guarantee that it will ever be consumed.
    #
    #  * :persistent
    # True or False. When true, this message will remain in the queue until 
    # it is consumed (if the queue is durable). When false, the message is
    # lost if the server restarts and the queue is recreated.
    #
    # For high-performance and low-latency, set :persistent => false so the
    # message stays in memory and is never persisted to non-volatile (slow)
    # storage.
    #
    def publish data, opts = {}
      @mq.callback{
        out = []

        out << Protocol::Basic::Publish.new({ :exchange => name,
                                              :routing_key => opts.delete(:key) || @key }.merge(opts))
      
        data = data.to_s

        out << Protocol::Header.new(Protocol::Basic,
                                    data.length, { :content_type => 'application/octet-stream',
                                                   :delivery_mode => (opts.delete(:persistent) ? 2 : 1),
                                                   :priority => 0 }.merge(opts))

        out << Frame::Body.new(data)

        @mq.send *out
      }
      self
    end

    # This method deletes an exchange.  When an exchange is deleted all queue
    # bindings on the exchange are cancelled.
    #
    # Further attempts to publish messages to a deleted exchange will raise
    # an MQ::Error due to a channel close exception.
    #
    #  exchange = MQ.direct('name', :key => 'foo.bar')
    #  exchange.delete
    #
    # == Options
    # * :nowait => true | false (default true)
    # If set, the server will not respond to the method. The client should
    # not wait for a reply method.  If the server could not complete the
    # method it will raise a channel or connection exception.
    #
    #  exchange.delete(:nowait => false)
    #
    # * :if_unused => true | false (default false)
    # If set, the server will only delete the exchange if it has no queue
    # bindings. If the exchange has queue bindings the server does not
    # delete it but raises a channel exception instead (MQ:Error).
    #    
    def delete opts = {}
      @mq.callback{
        @mq.send Protocol::Exchange::Delete.new({ :exchange => name,
                                                  :nowait => true }.merge(opts))
      }
      nil
    end
  end
end