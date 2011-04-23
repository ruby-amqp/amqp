# encoding: utf-8

require "amq/client/exchange"

module AMQP

  # h2. What are AMQP exchanges?
  #
  # AMQP exchange is where AMQP clients send messages. AMQP
  # exchange may also be described as a router or a matcher. Every
  # published message is received by an exchange which, depending on its
  # type and message attributes, determines how to deliver the message.
  #
  #
  # h2. Exchange types
  #
  # There are 4 supported exchange types: direct, fanout, topic and headers.
  #
  # As part of the standard, the server _must_ predeclare the direct exchange
  # 'amq.direct' and the fanout exchange 'amq.fanout'. All exchange names
  # starting with 'amq.' are reserved: attempts to declare an exchange using
  # 'amq.' as the name will raise an AMQP::Error and fail.
  #
  # Note that durability of exchanges and durability of messages published to exchanges
  # are different concepts. Sending messages to durable exchanges does not make
  # messages themselves persistent.
  #
  #
  # h2. AMQP bindings
  #
  # Closely related to exchange is a concept of bindings. A binding is
  # the relationship between an exchange and a message queue that tells
  # the exchange how to route messages. Bindings are set up by
  # AMQP applications (usually the app owning and using the message queue
  # sets up bindings for it). Exchange may be bound to none, 1 or more than 1
  # queue.
  #
  #
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
  #
  # h2. Direct exchanges
  #
  # Direct exchanges are useful for 1:1 communication scenarios.
  # Queues are bound to direct exchanges with a parameter called "routing key". When messages
  # arrive to a direct exchange, broker takes that message's routing key (if any), finds a queue bound
  # to the exchange with the same routing key and routes message there.
  #
  # Because very often queues are bound with the same routing key as queue's name, AMQP 0.9.1 has
  # a pre-declared direct exchange known as default exchange. Default exchange is a bit special: broker
  # automatically binds all the queues (in the same virtual host) to it with routing key equal to
  # queue names. In other words, messages delivered to default exchange are routed to queues when
  # message routing key equals queue name. Default exchange name is an empty string.
  #
  #
  #
  # h2. Fanout exchanges
  #
  # Fanout exchanges are useful for 1:n and n:m communication where one or more producer
  # feeds multiple consumers. messages published
  # to a fanout exchange are delivered to queues that are bound to that exchange name (unconditionally).
  # Each queue gets it's own copy of the message.
  #
  #
  #
  # h2. Topic exchanges
  #
  # Topic exchanges are used for 1:n and n:m communication scenarios.
  # Exchange of this type uses the routing key
  # to determine which queues to deliver the message. Wildcard matching
  # is allowed. The topic must be declared using dot notation to separate
  # each subtopic.
  #
  # As part of the AMQP standard, each server _should_ predeclare a topic
  # exchange called 'amq.topic'.
  #
  # The classic example is delivering market data. When publishing market
  # data for stocks, we may subdivide the stream based on 2
  # characteristics: nation code and trading symbol. The topic tree for
  # Apple may look like stock.us.aapl. NASDAQ updates may use topic stocks.us.nasdaq,
  # while DAX may use stock.de.dax.
  #
  # When publishing data to the exchange, bound queues subscribing to the
  # exchange indicate which data interests them by passing a routing key
  # for matching against the published routing key.
  #
  #
  # h2. Headers exchanges
  #
  # As part of the AMQP standard, each server _should_ predeclare a headers
  # exchange named 'amq.match'.
  #
  # When publishing data to the exchange, bound queues subscribing to the
  # exchange indicate which data interests them by passing arguments
  # for matching against the headers in published messages. The
  # form of the matching can be controlled by the 'x-match' argument, which
  # may be 'any' or 'all'. If unspecified, it defaults to "all".
  #
  # A value of 'all' for 'x-match' implies that all values must match (i.e.
  # it does an AND of the headers ), while a value of 'any' implies that
  # at least one should match (ie. it does an OR).
  #
  #
  # h2. Exchange durability and persistence of messages.
  #
  # AMQP separates concept of durability of entities (queues, exchanges) from messages persistence.
  # Exchanges can be durable or transient. Durable exchanges survive broker restart, transient exchanges don't (they
  # have to be redeclared when broker comes back online). Not all scenarios and use cases mandate exchanges to be
  # durable.
  #
  # The concept of messages persistence is separate: messages may be published as persistent. That makes
  # AMQP broker persist them to disk. If the server is restarted, the system ensures that received persistent messages
  # are not lost. Simply publishing message to a durable exchange or the fact that queue(s) they are routed to
  # is durable doesn't make messages persistent: it all depends on persistence mode of the messages itself.
  # Publishing messages as persistent affects performance (just like with data stores, durability comes at a certain cost
  # in performance and vise versa). Pass :persistent => true to {Exchange#publish} to publish your message as persistent.
  #
  # Note that *only durable queues can be bound to durable exchanges*.
  #
  #
  # h2. RabbitMQ extensions.
  #
  # AMQP gem supports several RabbitMQ extensions taht extend Exchange functionality.
  # Learn more in {file:docs/VendorSpecificExtensions.textile}
  #
  #
  # h2. Key methods
  #
  # Key methods of Exchange class are
  #
  # * {Exchange#publish}
  # * {Exchange#delete}
  # * {Exchange.default}
  #
  #
  # @note Please make sure you read a section on exchanges durability vs. messages
  #       persistence.
  #
  # @see http://www.rabbitmq.com/faq.html#managing-concepts-exchanges Exchanges explained in the RabbitMQ FAQ
  # @see http://www.rabbitmq.com/faq.html#Binding-and-Routing Bindings and routing explained in the RabbitMQ FAQ
  # @see Channel#default_exchange
  # @see Channel#direct
  # @see Channel#fanout
  # @see Channel#topic
  # @see Channel#headers
  # @see Queue
  # @see http://bit.ly/hw2ELX AMQP 0.9.1 specification (Section 2.1.1)
  # @see http://bit.ly/hw2ELX AMQP 0.9.1 specification (Section 2.1.5)
  # @see http://bit.ly/hw2ELX AMQP 0.9.1 specification (Section 3.1.3)
  class Exchange < AMQ::Client::Exchange

    #
    # API
    #

    DEFAULT_CONTENT_TYPE = "application/octet-stream".freeze


    # The default exchange. Default exchange is a direct exchange that is predefined.
    # It cannot be removed. Every queue is bind to this (direct) exchange by default with
    # the following routing semantics: messages will be routed to the queue withe same
    # same name as message's routing key. In other words, if a message is published with
    # a routing key of "weather.usa.ca.sandiego" and there is a queue Q with this name,
    # that message will be routed to Q.
    #
    # @param [AMQP::Channel] channel Channel to use. If not given, new AMQP channel
    #                                will be opened on the default AMQP connection (accessible as AMQP.connection).
    #
    # @example Publishing a messages to the tasks queue
    #   channel     = AMQP::Channel.new(connection)
    #   tasks_queue = channel.queue("tasks")
    #   AMQP::Exchange.default(channel).publish("make clean", routing_key => "tasks")
    #
    # @see Exchange
    # @see http://bit.ly/hw2ELX AMQP 0.9.1 specification (Section 2.1.2.4)
    # @note Do not confuse default exchange with amq.direct: amq.direct is a pre-defined direct
    #       exchange that doesn't have any special routing semantics.
    # @return [Exchange] An instance that corresponds to the default exchange (of type direct).
    # @api public
    def self.default(channel = nil)
      self.new(channel || AMQP::Channel.new, :direct, AMQ::Protocol::EMPTY_STRING, :no_declare => true)
    end


    # @return [String]
    attr_reader :name

    # Type of this exchange (one of: :direct, :fanout, :topic, :headers).
    # @return [Symbol]
    attr_reader :type

    # @return [Symbol]
    # @api plugin
    attr_reader :status

    # Options hash this exchange instance was instantiated with
    # @return [Hash]
    attr_accessor :opts

    # @return [#call] A callback that is executed once declaration notification (exchange.declare-ok)
    #                 from the broker arrives.
    attr_accessor :on_declare

    # @return [String]
    attr_reader :default_routing_key
    alias key default_routing_key

    # Compatibility alias for #on_declare.
    #
    # @api public
    # @deprecated
    # @return [#call]
    def callback
      @on_declare
    end



    # See {Exchange Exchange class documentation} for introduction, information about exchange types,
    # what uses cases they are good for and so on.
    #
    # h2. Predeclared exchanges
    #
    # If exchange name corresponds to one of those predeclared by AMQP 0.9.1 specification (empty string, amq.direct, amq.fanout, amq.topic, amq.match),
    # declaration command won't be sent to the broker (because the only possible reply from the broker is to reject it, predefined entities cannot be changed).
    # Callback, if any, will be executed immediately.
    #
    #
    #
    # @example Instantiating a fanout exchange using constructor
    #
    #   AMQP.connect do |connection|
    #     AMQP::Channel.new(connection) do |channel|
    #       AMQP::Exchange.new(channel, :fanout, "search.index.updates") do |exchange, declare_ok|
    #         # by now exchange is ready and waiting
    #       end
    #     end
    #   end
    #
    #
    # @example Instantiating a direct exchange using {Channel#direct}
    #
    #   AMQP.connect do |connection|
    #     AMQP::Channel.new(connection) do |channel|
    #       channel.direct("email.replies_listener") do |exchange, declare_ok|
    #         # by now exchange is ready and waiting
    #       end
    #     end
    #   end
    #
    #
    # @param [Channel] channel AMQP channel this exchange is associated with
    # @param [Symbol]  type    Exchange type
    # @param [String]  name    Exchange name
    #
    #
    # @option opts [Boolean] :passive (false)  If set, the server will not create the exchange if it does not
    #                                          already exist. The client can use this to check whether an exchange
    #                                          exists without modifying the server state.
    #
    # @option opts [Boolean] :durable (false)  If set when creating a new exchange, the exchange will be marked as
    #                                          durable. Durable exchanges and their bindings are recreated upon a server
    #                                          restart (information about them is persisted). Non-durable (transient) exchanges
    #                                          do not survive if/when a server restarts (information about them is stored exclusively
    #                                          in RAM).
    #
    #
    # @option opts [Boolean] :auto_delete  (false)  If set, the exchange is deleted when all queues have finished
    #                                               using it. The server waits for a short period of time before
    #                                               determining the exchange is unused to give time to the client code
    #                                               to bind a queue to it.
    #
    # @option opts [Boolean] :internal (false)      If set, the exchange may not be used directly by publishers, but
    #                                               only when bound to other exchanges. Internal exchanges are used to
    #                                               construct wiring that is not visible to applications. *This is a RabbitMQ-specific
    #                                               extension.*
    #
    # @option opts [Boolean] :nowait (true)         If set, the server will not respond to the method. The client should
    #                                               not wait for a reply method.  If the server could not complete the
    #                                               method it will raise a channel or connection exception.
    #
    # @option opts [Boolean] :no_declare (true)     If set, exchange declaration command won't be sent to the broker. Allows to forcefully
    #                                               avoid declaration. We recommend that only experienced developers consider this option.
    #
    # @option opts [String] :default_routing_key (nil)  Default routing key that will be used by {Exchange#publish} when no routing key is not passed explicitly.
    #                                                   It is perfectly fine for applications to always specify routing key to {Exchange#publish}.
    #
    # @option opts [Hash] :arguments (nil)  A hash of optional arguments with the declaration. Some brokers implement
    #                                          AMQP extensions using x-prefixed declaration arguments.
    #
    #
    # @raise [AMQP::Error] Raised when exchange is redeclared with parameters different from original declaration.
    # @raise [AMQP::Error] Raised when exchange is declared with :passive => true and the exchange does not exist.
    #
    # @yield [exchange, declare_ok] Yields successfully declared exchange instance and AMQP method (exchange.declare-ok) instance. The latter is optional.
    # @yieldparam [Exchange] exchange Exchange that is successfully declared and is ready to be used.
    # @yieldparam [AMQP::Protocol::Exchange::DeclareOk] declare_ok AMQP exchange.declare-ok) instance.
    #
    # @see Channel#default_exchange
    # @see Channel#direct
    # @see Channel#fanout
    # @see Channel#topic
    # @see Channel#headers
    # @see Queue
    # @see http://bit.ly/hw2ELX AMQP 0.9.1 specification (Section 3.1.3)
    #
    # @return [Exchange]
    # @api public
    def initialize(channel, type, name, opts = {}, &block)
      @channel             = channel
      @type                = type
      @opts                = self.class.add_default_options(type, name, opts, block)
      @default_routing_key = opts[:routing_key] || opts[:key]
      @name                = name unless name.empty?

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
      unless name == "amq.#{type}" or name.empty? or opts[:no_declare]
        @status = :opening

        shim = Proc.new do |exchange, declare_ok|
          case block.arity
          when 1 then block.call(exchange)
          else
            block.call(exchange, declare_ok)
          end
        end

        unless @opts[:no_declare]
          @channel.once_open do
            self.declare(passive = @opts[:passive], durable = @opts[:durable], exclusive = @opts[:exclusive], auto_delete = @opts[:auto_delete], nowait = @opts[:nowait], @opts[:arguments], &shim)
          end
        end
      else
        # Call the callback immediately, as given exchange is already
        # declared.
        @status = :opened
        block.call(self) if block
      end

      @on_declare = block
    end

    # @return [Channel]
    # @api public
    def channel
      @channel
    end

    # Publishes message to the exchange. The message will be routed to queues by the exchange
    # and distributed to any active consumers. Routing logic is determined by exchange type and
    # configuration as well as  message attributes (like :routing_key).
    #
    # h2. Data serialization
    #
    # Note that this method calls #to_s on payload argument value. You are encouraged to take care of
    # data serialization before publishing (using JSON, Thrift, Protocol Buffers or other serialization library).
    # Note that because AMQP is a binary protocol, text formats like JSON lose lose their strong point of being easy
    # to inspect data as it travels across network.
    #
    #
    #
    # h2. Event loop blocking
    #
    # To minimize blocking of EventMachine event loop, this method performs network I/O on the next event loop tick.
    #
    # @param  [#to_s] payload  Message payload (content). Note that this method calls #to_s on payload argument value.
    #                          You are encouraged to take care of data serialization before publishing (using JSON, Thrift,
    #                          Protocol Buffers or other serialization library).
    #
    # @option options [String] :routing_key (nil)  Specifies message routing key. Routing key determines
    #                                      what queues messages are delivered to (exact routing algorithms vary
    #                                      between exchange types).
    #
    # @option options [Boolean] :mandatory (false) This flag tells the server how to react if the message cannot be
    #                                      routed to a queue. If message is mandatory, the server will return
    #                                      unroutable message back to the client with basic.return AMQPmethod.
    #                                      If message is not mandatory, the server silently drops the message.
    #
    # @option options [Boolean] :immediate (false) This flag tells the server how to react if the message cannot be
    #                                      routed to a queue consumer immediately.  If this flag is set, the
    #                                      server will return an undeliverable message with a Return method.
    #                                      If this flag is zero, the server will queue the message, but with
    #                                      no guarantee that it will ever be consumed.
    #
    # @option options [Boolean] :persistent (false) When true, this message will be persisted to disk and remain in the queue until
    #                                       it is consumed. When false, the message is only kept in a transient store
    #                                       and will lost in case of server restart.
    #                                       When performance and latency are more important than durability, set :persistent => false.
    #                                       If durability is more important, set :persistent => true.
    #
    # @option options [String] :content_type (application/octet-stream) Content-type of message payload.
    #
    #
    # @example Publishing without routing key
    #  exchange = channel.fanout('search.indexer')
    #  # fanout exchanges deliver messages to bound queues unconditionally,
    #  # so routing key is unnecessary here
    #  exchange.publish("some data")
    #
    # @example Publishing with a routing key
    #  exchange = channel.direct('search.indexer')
    #  exchange.publish("some data", :routing_key => "search.index.updates")
    #
    # @return [Exchange] self
    #
    # @note Please make sure you read {Exchange Exchange class} documentation section on exchanges durability vs. messages
    #       persistence.
    # @api public
    def publish(payload, options = {}, &block)
      EM.next_tick do
        opts    = @default_publish_options.merge(options)

        @channel.once_open do
          super(payload.to_s, opts[:key] || opts[:routing_key] || @default_routing_key, @default_headers.merge(options), opts[:mandatory], opts[:immediate], &block)
        end
      end

      self
    end


    # This method deletes an exchange.  When an exchange is deleted all queue
    # bindings on the exchange are cancelled.
    #
    # Further attempts to publish messages to a deleted exchange will raise
    # an AMQP::Channel::Error due to a channel close exception.
    #
    #  exchange = AMQP::Channel.direct('name', :routing_key => 'foo.bar')
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
      @channel.once_open do
        super(opts.fetch(:if_unused, false), opts.fetch(:nowait, false), &block)
      end

      # backwards compatibility
      nil
    end

    # @return [Boolean] true if this exchange is durable
    # @note Please make sure you read {Exchange Exchange class} documentation section on exchanges durability vs. messages
    #       persistence.
    # @api public
    def durable?
      !!@opts[:durable]
    end # durable?

    # @return [Boolean] true if this exchange is transient (non-durable)
    # @note Please make sure you read {Exchange Exchange class} documentation section on exchanges durability vs. messages
    #       persistence.
    # @api public
    def transient?
      !self.durable?
    end # transient?
    alias temporary? transient?

    # @return [Boolean] true if this exchange is automatically deleted when it is no longer used
    # @api public
    def auto_deleted?
      !!@opts[:auto_delete]
    end # auto_deleted?
    alias auto_deletable? auto_deleted?

    # Resets queue state. Useful for error handling.
    # @api plugin
    def reset
      initialize(@channel, @type, @name, @opts)
    end


    protected

    # @private
    def self.add_default_options(type, name, opts, block)
      { :exchange => name, :type => type, :nowait => block.nil? }.merge(opts)
    end
  end # Exchange
end # AMQP
