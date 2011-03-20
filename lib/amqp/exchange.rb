# encoding: utf-8

require "amq/client/exchange"

module AMQP
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
  # 'amq.' as the name will raise an AMQP::Error and fail. In practice these
  # default exchanges are never used directly by client code.
  #
  # These predececlared exchanges are used when the client code declares
  # an exchange without a name. In these cases the library will use
  # the default exchange for publishing the messages.
  #
  class Exchange < AMQ::Client::Exchange

    #
    # API
    #


    # The default exchange.
    # Every queue is bind to this (direct) exchange by default.
    # You can't remove it or bind there queue explicitly.
    #
    # Do NOT confuse with amq.direct: it's only a normal direct
    # exchange and the only special thing about it is that it's
    # predefined in the system, so you can use it straightaway.
    #
    # Example:
    # AMQP::Channel.new.queue("tasks")
    # AMQP::Channel::Exchange.default.publish("make clean", routing_key: "tasks")
    #
    # For more info see section 2.1.2.4 Automatic Mode of the AMQP 0.9.1 spec.
    # @api public
    def self.default(channel = nil)
      self.new(channel || AMQP::Channel.new, :direct, AMQ::Protocol::EMPTY_STRING, :no_declare => true)
    end



    attr_reader :name, :type, :key, :status
    attr_accessor :opts, :on_declare

    # Compatibility alias for #on_declare.
    #
    # @api public
    # @deprecated
    def callback
      @on_declare
    end

    # Defines, intializes and returns an Exchange to act as an ingress
    # point for all published messages.
    #
    # There are three (3) supported Exchange types: direct, fanout and topic.
    #
    # As part of the standard, the server _must_ predeclare the direct exchange
    # 'amq.direct' and the fanout exchange 'amq.fanout' (all exchange names
    # starting with 'amq.' are reserved). Attempts to declare an exchange using
    # 'amq.' as the name will raise an AMQP::Error and fail. In practice these
    # default exchanges are never used directly by client code.
    #
    # == Direct
    # A direct exchange is useful for 1:1 communication between a publisher and
    # subscriber. Messages are routed to the queue with a binding that shares
    # the same name as the exchange. Alternately, the messages are routed to
    # the bound queue that shares the same name as the routing key used for
    # defining the exchange. This exchange type does not honor the :key option
    # when defining a new instance with a name. It _will_ honor the :key option
    # if the exchange name is the empty string. This is because an exchange
    # defined with the empty string uses the default pre-declared exchange
    # called 'amq.direct'. In this case it needs to use :key to do its matching.
    #
    #  # exchange is named 'foo'
    #  exchange = AMQP::Channel::Exchange.new(AMQP::Channel.new, :direct, 'foo')
    #
    #  # or, the exchange can use the default name (amq.direct) and perform
    #  # routing comparisons using the :key
    #  exchange = AMQP::Channel::Exchange.new(AMQP::Channel.new, :direct, "", :key => 'foo')
    #  exchange.publish('some data') # will be delivered to queue bound to 'foo'
    #
    #  queue = AMQP::Channel::Queue.new(AMQP::Channel.new, 'foo')
    #  # can receive data since the queue name and the exchange key match exactly
    #  queue.pop { |data| puts "received data [#{data}]" }
    #
    # == Fanout
    # A fanout exchange is useful for 1:N communication where one publisher
    # feeds multiple subscribers. Like direct exchanges, messages published
    # to a fanout exchange are delivered to queues whose name matches the
    # exchange name (or are bound to that exchange name). Each queue gets
    # its own copy of the message.
    #
    # Like the direct exchange type, this exchange type does not honor the
    # :key option when defining a new instance with a name. It _will_ honor
    # the :key option if the exchange name is the empty string. Fanout exchanges
    # defined with the empty string as the name use the default 'amq.fanout'.
    # In this case it needs to use :key to do its matching.
    #
    #  EM.run do
    #    clock = AMQP::Channel::Exchange.new(AMQP::Channel.new, :fanout, 'clock')
    #    EM.add_periodic_timer(1) do
    #      puts "\npublishing #{time = Time.now}"
    #      clock.publish(Marshal.dump(time))
    #    end
    #
    #    # one way of defining a queue
    #    amq = AMQP::Channel::Queue.new(AMQP::Channel.new, 'every second')
    #    amq.bind(AMQP::Channel.fanout('clock')).subscribe do |time|
    #      puts "every second received #{Marshal.load(time)}"
    #    end
    #
    #    # defining a queue using the convenience method
    #    # note the string passed to #bind
    #    AMQP::Channel.queue('every 5 seconds').bind('clock').subscribe do |time|
    #      time = Marshal.load(time)
    #      puts "every 5 seconds received #{time}" if time.strftime('%S').to_i%5 == 0
    #    end
    #  end
    #
    # == Topic
    # A topic exchange allows for messages to be published to an exchange
    # tagged with a specific routing key. The Exchange uses the routing key
    # to determine which queues to deliver the message. Wildcard matching
    # is allowed. The topic must be declared using dot notation to separate
    # each subtopic.
    #
    # This is the only exchange type to honor the :key parameter.
    #
    # As part of the AMQP standard, each server _should_ predeclare a topic
    # exchange called 'amq.topic' (this is not required by the standard).
    #
    # The classic example is delivering market data. When publishing market
    # data for stocks, we may subdivide the stream based on 2
    # characteristics: nation code and trading symbol. The topic tree for
    # Apple Computer would look like:
    #  'stock.us.aapl'
    # For a foreign stock, it may look like:
    #  'stock.de.dax'
    #
    # When publishing data to the exchange, bound queues subscribing to the
    # exchange indicate which data interests them by passing a routing key
    # for matching against the published routing key.
    #
    #  EM.run do
    #    exch = AMQP::Channel::Exchange.new(AMQP::Channel.new, :topic, "stocks")
    #    keys = ['stock.us.aapl', 'stock.de.dax']
    #
    #    EM.add_periodic_timer(1) do # every second
    #      puts
    #      exch.publish(10+rand(10), :routing_key => keys[rand(2)])
    #    end
    #
    #    # match against one dot-separated item
    #    AMQP::Channel.queue('us stocks').bind(exch, :key => 'stock.us.*').subscribe do |price|
    #      puts "us stock price [#{price}]"
    #    end
    #
    #    # match against multiple dot-separated items
    #    AMQP::Channel.queue('all stocks').bind(exch, :key => 'stock.#').subscribe do |price|
    #      puts "all stocks: price [#{price}]"
    #    end
    #
    #    # require exact match
    #    AMQP::Channel.queue('only dax').bind(exch, :key => 'stock.de.dax').subscribe do |price|
    #      puts "dax price [#{price}]"
    #    end
    #  end
    #
    # For matching, the '*' (asterisk) wildcard matches against one
    # dot-separated item only. The '#' wildcard (hash or pound symbol)
    # matches against 0 or more dot-separated items. If none of these
    # symbols are used, the exchange performs a comparison looking for an
    # exact match.
    #
    # == Options
    # * :passive => true | false (default false)
    # If set, the server will not create the exchange if it does not
    # already exist. The client can use this to check whether an exchange
    # exists without modifying  the server state.
    #
    # * :durable => true | false (default false)
    # If set when creating a new exchange, the exchange will be marked as
    # durable.  Durable exchanges remain active when a server restarts.
    # Non-durable exchanges (transient exchanges) are purged if/when a
    # server restarts.
    #
    # A transient exchange (the default) is stored in memory-only
    # therefore it is a good choice for high-performance and low-latency
    # message publishing.
    #
    # Durable exchanges cause all messages to be written to non-volatile
    # backing store (i.e. disk) prior to routing to any bound queues.
    #
    # * :auto_delete => true | false (default false)
    # If set, the exchange is deleted when all queues have finished
    # using it. The server waits for a short period of time before
    # determining the exchange is unused to give time to the client code
    # to bind a queue to it.
    #
    # If the exchange has been previously declared, this option is ignored
    # on subsequent declarations.
    #
    # * :internal => true | false (default false)
    # If set, the exchange may not be used directly by publishers, but
    # only when bound to other exchanges. Internal exchanges are used to
    # construct wiring that is not visible to applications.
    #
    # * :nowait => true | false (default true)
    # If set, the server will not respond to the method. The client should
    # not wait for a reply method.  If the server could not complete the
    # method it will raise a channel or connection exception.
    #
    # * :no_declare => true | false (default false)
    # If set, the exchange will not be declared to the
    # AMQP broker at instantiation-time. This allows the AMQP
    # client to send messages to exchanges that were
    # already declared by someone else, e.g. if the client
    # does not have sufficient privilege to declare (create)
    # an exchange. Use with caution, as binding to an exchange
    # with the no-declare option causes your system to become
    # sensitive to the ordering of clients' actions!
    #
    # == Exceptions
    # Doing any of these activities are illegal and will raise exceptions:
    #
    # * redeclare an already-declared exchange to a different type (raises AMQP::Channel::IncompatibleOptionsError)
    # * :passive => true and the exchange does not exist (NOT_FOUND)
    #
    # @api public
    def initialize(channel, type, name, opts = {}, &block)
      @channel = channel
      @type    = type
      @opts    = self.class.add_default_options(type, name, opts, block)
      @key     = opts[:key]
      @name    = name unless name.empty?

      @status                  = :unknown
      @default_publish_options = (opts.delete(:default_publish_options) || {
        :routing_key  => AMQ::Protocol::EMPTY_STRING,
        :mandatory    => false,
        :immediate    => false
      }).freeze

      @default_headers = (opts.delete(:default_headers) || {
        :content_type => DEFAULT_CONTENT_TYPE,
        :persistent   => false,
        :priority     => 0
      }).freeze

      super(channel.connection, channel, name, type)

      # The AMQP 0.8 specification (as well as 0.9.1) in 1.1.4.2 mentiones
      # that Exchange.Declare-Ok confirms the name of the exchange (because
      # of automatically­named), which is logical to interpret that this
      # functionality should be the same as for Queue (though it isn't
      # explicitely told in the specification). In fact, RabbitMQ (and
      # probably other implementations as well) doesn't support it and
      # there is a default exchange with an empty name (so-called default
      # or nameless exchange), so if we'd send Exchange.Declare(exchange=""),
      # then RabbitMQ interpret it as if we'd try to redefine this default
      # exchange so it'd produce an error.
      unless name == "amq.#{type}" or name == AMQ::Protocol::EMPTY_STRING or opts[:no_declare]
        @status = :unfinished
        self.declare(passive = @opts[:passive], durable = @opts[:durable], exclusive = @opts[:exclusive], auto_delete = @opts[:auto_delete], nowait = @opts[:nowait], nil, &block) unless @opts[:no_declare]
      else
        # Call the callback immediately, as given exchange is already
        # declared.
        @status = :finished
        block.call(self) if block
      end

      @on_declare = block
    end

    # @api public
    def channel
      @channel
    end

    # This method publishes a staged file message to a specific exchange.
    # The file message will be routed to queues as defined by the exchange
    # configuration and distributed to any active consumers when the
    # transaction, if any, is committed.
    #
    #  exchange = AMQP::Channel.direct('name', :key => 'foo.bar')
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
    #  * :persistent => true | false (default false)
    # When true, this message will remain in the queue until
    # it is consumed (if the queue is durable). When false, the message is
    # lost if the server restarts and the queue is recreated.
    #
    # For high-performance and low-latency, set :persistent => false so the
    # message stays in memory and is never persisted to non-volatile (slow)
    # storage (like disk).
    #
    #  * :content_type
    # Content type you want to send the message with. It defaults to "application/octet-stream".
    #
    # @api public
    def publish(payload, options = {})
      EM.next_tick do
        opts    = @default_publish_options.merge(options)

        super(payload, opts[:key] || opts[:routing_key], @default_headers.merge(options), opts[:mandatory], opts[:immediate])
      end
    end

    DEFAULT_CONTENT_TYPE = "application/octet-stream".freeze


    # This method deletes an exchange.  When an exchange is deleted all queue
    # bindings on the exchange are cancelled.
    #
    # Further attempts to publish messages to a deleted exchange will raise
    # an AMQP::Channel::Error due to a channel close exception.
    #
    #  exchange = AMQP::Channel.direct('name', :key => 'foo.bar')
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
    # delete it but raises a channel exception instead (AMQP::Error).
    #
    # @api public
    def delete(opts = {}, &block)
      super(opts.fetch(:if_unused, false), opts.fetch(:nowait, false), &block)

      # backwards compatibility
      nil
    end

    # @api public
    def durable?
      !!@opts[:durable]
    end # durable?

    # @api public
    def transient?
      !self.durable?
    end # transient?

    # @api public
    def auto_deleted?
      !!@opts[:auto_delete]
    end # auto_deleted?
    alias auto_deletable? auto_deleted?


    # @api plugin
    def reset
      @deferred_status = nil
      initialize @mq, @type, @name, @opts
    end


    protected

    def self.add_default_options(type, name, opts, block)
      { :exchange => name, :type => type, :nowait => block.nil? }.merge(opts)
    end
  end # Exchange
end # AMQP
