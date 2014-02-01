# encoding: utf-8

module AMQP

  # h2. What are AMQP exchanges?
  #
  # AMQP exchange is where AMQP clients send messages. AMQP
  # exchange may also be described as a router or a matcher. Every
  # published message is received by an exchange which, depending on its
  # type and message attributes, determines how to deliver the message.
  #
  #
  # Entities that forward messages to consumers (or consumers fetch messages
  # from on demand) are called {Queue queues}. Exchanges are associated with
  # queues via bindings. Roughly speaking, bindings determine messages placed
  # in what exchange end up in what queues.
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
  # h2. Exchange types
  #
  # There are 4 supported exchange types: direct, fanout, topic and headers.
  # Exchange type determines how exchange processes and routes messages.
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
  # As part of the standard, the server _must_ predeclare the direct exchange
  # 'amq.direct' and the fanout exchange 'amq.fanout' (all exchange names
  # starting with 'amq.' are reserved). Attempts to declare an exchange using
  # 'amq.' as the name will result in a channel-level exception and fail. In practice these
  # default exchanges are never used directly by client code.
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
  # When publishing data to exchange of type headers, bound queues subscribing to the
  # exchange indicate which data interests them by passing arguments
  # for matching against the headers in published messages. The
  # form of the matching can be controlled by the 'x-match' argument, which
  # may be 'any' or 'all'. If unspecified, it defaults to "all".
  #
  # A value of 'all' for 'x-match' implies that all values must match (i.e.
  # it does an AND of the headers ), while a value of 'any' implies that
  # at least one should match (ie. it does an OR).
  #
  # As part of the AMQP standard, each server _should_ predeclare a headers
  # exchange named 'amq.match'.
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
  #
  # h2. Exchange durability and persistence of messages.
  #
  # Learn more in our {file:docs/Durability.textile Durability guide}.
  #
  #
  #
  # h2. RabbitMQ extensions.
  #
  # AMQP gem supports several RabbitMQ extensions taht extend Exchange functionality.
  # Learn more in {file:docs/VendorSpecificExtensions.textile}
  #
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
  # @see http://files.travis-ci.org/docs/amqp/0.9.1/AMQP091Specification.pdf AMQP 0.9.1 specification (Section 2.1.1)
  # @see http://files.travis-ci.org/docs/amqp/0.9.1/AMQP091Specification.pdf AMQP 0.9.1 specification (Section 2.1.5)
  # @see http://files.travis-ci.org/docs/amqp/0.9.1/AMQP091Specification.pdf AMQP 0.9.1 specification (Section 3.1.3)
  class Exchange


    #
    # Behaviours
    #

    include Entity
    extend  ProtocolMethodHandlers


    #
    # API
    #

    DEFAULT_CONTENT_TYPE = "application/octet-stream".freeze
    BUILTIN_TYPES = [:fanout, :direct, :topic, :headers].freeze


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
    # @see http://files.travis-ci.org/docs/amqp/0.9.1/AMQP091Specification.pdf AMQP 0.9.1 specification (Section 2.1.2.4)
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

    # Channel this exchange belongs to.
    attr_reader :channel

    # @return [Hash] Additional arguments given on queue declaration. Typically used by AMQP extensions.
    attr_reader :arguments


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
    # @see http://files.travis-ci.org/docs/amqp/0.9.1/AMQP091Specification.pdf AMQP 0.9.1 specification (Section 3.1.3)
    #
    # @return [Exchange]
    # @api public
    def initialize(channel, type, name, opts = {}, &block)
      @channel             = channel
      @type                = type
      @opts                = self.class.add_default_options(type, name, opts, block)
      @default_routing_key = opts[:routing_key] || opts[:key] || AMQ::Protocol::EMPTY_STRING
      @name                = name unless name.empty?

      @status                  = :unknown
      @default_publish_options = (opts.delete(:default_publish_options) || {
          :routing_key  => @default_routing_key,
          :mandatory    => false
        }).freeze

      @default_headers = (opts.delete(:default_headers) || {
          :content_type => DEFAULT_CONTENT_TYPE,
          :persistent   => false,
          :priority     => 0
        }).freeze

      if !(BUILTIN_TYPES.include?(type.to_sym) || type.to_s =~ /^x-.+/i)
        raise UnknownExchangeTypeError.new(BUILTIN_TYPES, type)
      end

      @channel    = channel
      @name       = name
      @type       = type

      # register pre-declared exchanges
      if @name == AMQ::Protocol::EMPTY_STRING || @name =~ /^amq\.(direct|fanout|topic|match|headers)/
        @channel.register_exchange(self)
      end

      super(channel.connection)

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

        unless @opts[:no_declare]
          @channel.once_open do
            if block
              shim = Proc.new do |exchange, declare_ok|
                case block.arity
                when 1 then block.call(exchange)
                else
                  block.call(exchange, declare_ok)
                end
              end

              self.exchange_declare(@opts[:passive], @opts[:durable], @opts[:auto_delete], @opts[:internal], @opts[:nowait], @opts[:arguments], &shim)
            else
              self.exchange_declare(@opts[:passive], @opts[:durable], @opts[:auto_delete], @opts[:internal], @opts[:nowait], @opts[:arguments])
            end
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

    # @return [Boolean] true if this exchange is of type `fanout`
    # @api public
    def fanout?
      @type == :fanout
    end

    # @return [Boolean] true if this exchange is of type `direct`
    # @api public
    def direct?
      @type == :direct
    end

    # @return [Boolean] true if this exchange is of type `topic`
    # @api public
    def topic?
      @type == :topic
    end

    # @return [Boolean] true if this exchange is of type `headers`
    # @api public
    def headers?
      @type == :headers
    end

    # @return [Boolean] true if this exchange is of a custom type (begins with x-)
    # @api public
    def custom_type?
      @type.to_s =~ /^x-.+/i
    end # custom_type?

    # @return [Boolean] true if this exchange is a pre-defined one (amq.direct, amq.fanout, amq.match and so on)
    def predefined?
      @name && ((@name == AMQ::Protocol::EMPTY_STRING) || !!(@name =~ /^amq\.(direct|fanout|topic|headers|match)/i))
    end # predefined?

    # @return [Boolean] true if this exchange is an internal exchange
    def internal?
      @opts[:internal]
    end

    # Publishes message to the exchange. The message will be routed to queues by the exchange
    # and distributed to any active consumers. Routing logic is determined by exchange type and
    # configuration as well as message attributes (like :routing_key or message headers).
    #
    # Published data is opaque and not modified by Ruby amqp gem in any way. Serialization of data with JSON, Thrift, BSON
    # or similar libraries before publishing is very common.
    #
    #
    # h2. Data serialization
    #
    # Note that this method calls #to_s on payload argument value. Applications are encouraged of
    # data serialization before publishing (using JSON, Thrift, Protocol Buffers or other serialization library).
    # Note that because AMQP is a binary protocol, text formats like JSON largely lose their strong point of being easy
    # to inspect as data travels across network, so "BSON":http://bsonspec.org may be a good fit.
    #
    #
    # h2. Publishing and message persistence
    #
    # In cases when you application cannot afford to lose a message, AMQP 0.9.1 has several features to offer:
    #
    # * Persistent messages
    # * Messages acknowledgements
    # * Transactions
    # * (a RabbitMQ-specific extension) Publisher confirms
    #
    # This is a broad topic and we dedicate a separate guide, {file:docs/Durability.textile Durability and message persistence}, to it.
    #
    #
    # h2. Publishing callback and guarantees it DOES NOT offer
    #
    # Exact moment when message is published is not determined and depends on many factors, including machine's networking stack configuration,
    # so (optional) block this method takes is scheduled for next event loop tick, and data is staged for delivery for current event loop
    # tick. For most applications, this is good enough. The only way to guarantee a message was delivered in a distributed system is to
    # ask a peer to send you a message back. RabbitMQ
    #
    # @note Optional callback this method takes DOES NOT OFFER ANY GUARANTEES ABOUT DATA DELIVERY and must not be used as a "delivery callback".
    #       The only way to guarantee delivery in distributed environment is to use an acknowledgement mechanism, such as AMQP transactions
    #       or lightweight "publisher confirms" RabbitMQ extension supported by amqp gem. See {file:docs/Durability.textile Durability and message persistence}
    #       and {file:docs/Exchanges.textile Working With Exchanges} guides for details.
    #
    #
    # h2. Event loop blocking
    #
    # When intermixing publishing of many messages with other workload that may take some time, even loop blocking may affect the performance.
    # There are several ways to avoid it:
    #
    # * Run EventMachine in a separate thread.
    # * Use EventMachine.next_tick.
    # * Use EventMachine.defer to offload operation to EventMachine thread pool.
    #
    # TBD: this subject is worth a separate guide
    #
    #
    # h2. Sending one-off messages
    #
    # If you need to send a one-off message and then stop the event loop, pass a block to {Exchange#publish} that will be executed
    # after message is pushed down the network stack, and use {AMQP::Session#disconnect} to properly tear down AMQP connection
    # (see example under Examples section below).
    #
    # @example Publishing a one-off message and properly closing AMQP connection then stopping the event loop:
    #   exchange.publish(data) do
    #     connection.disconnect { EventMachine.stop }
    #   end
    #
    #
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
    # @note Please make sure you read {file:docs/Durability.textile Durability an message persistence} guide that covers exchanges durability vs. messages
    #       persistence.
    # @api public
    def publish(payload, options = {}, &block)
      opts    = @default_publish_options.merge(options)

      @channel.once_open do
        properties                 = @default_headers.merge(options)
        properties[:delivery_mode] = properties.delete(:persistent) ? 2 : 1
        basic_publish(payload.to_s, opts[:key] || opts[:routing_key] || @default_routing_key, properties, opts[:mandatory])

        # don't pass block to AMQP::Exchange#publish because it will be executed
        # immediately and we want to do it later. See ruby-amqp/amqp/#67 MK.
        EventMachine.next_tick(&block) if block
      end

      self
    end


    # This method deletes an exchange. When an exchange is deleted all queue bindings on the exchange are deleted, too.
    # Further attempts to publish messages to a deleted exchange will result in a channel-level exception.
    #
    # @example Deleting an exchange
    #
    #  exchange = AMQP::Channel.direct("search.indexing")
    #  exchange.delete
    #
    # @option opts [Boolean] :nowait (false) If set, the server will not respond to the method. The client should
    #                                        not wait for a reply method.  If the server could not complete the
    #                                        method it will raise a channel or connection exception.
    #
    # @option opts [Boolean] :if_unused (false) If set, the server will only delete the exchange if it has no queue
    #                                           bindings. If the exchange has queue bindings the server does not
    #                                           delete it but raises a channel exception instead.
    #
    # @return [NilClass] nil
    # @api public
    def delete(opts = {}, &block)
      @channel.once_open do
        exchange_delete(opts.fetch(:if_unused, false), opts.fetch(:nowait, false), &block)
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


    # @group Declaration

    # @api public
    def exchange_declare(passive = false, durable = false, auto_delete = false, internal = false, nowait = false, arguments = nil, &block)
      # for re-declaration
      @passive     = passive
      @durable     = durable
      @auto_delete = auto_delete
      @arguments   = arguments
      @internal    = internal

      @connection.send_frame(AMQ::Protocol::Exchange::Declare.encode(@channel.id, @name, @type.to_s, passive, durable, auto_delete, internal, nowait, arguments))

      unless nowait
        self.define_callback(:declare, &block)
        @channel.exchanges_awaiting_declare_ok.push(self)
      end

      self
    end


    # @api public
    def redeclare(&block)
      nowait = block.nil?
      @connection.send_frame(AMQ::Protocol::Exchange::Declare.encode(@channel.id, @name, @type.to_s, @passive, @durable, @auto_delete, @internal, nowait, @arguments))

      unless nowait
        self.define_callback(:declare, &block)
        @channel.exchanges_awaiting_declare_ok.push(self)
      end

      self
    end # redeclare(&block)

    # @endgroup


    # @api public
    def exchange_delete(if_unused = false, nowait = false, &block)
      @connection.send_frame(AMQ::Protocol::Exchange::Delete.encode(@channel.id, @name, if_unused, nowait))

      unless nowait
        self.define_callback(:delete, &block)

        # TODO: delete itself from exchanges cache
        @channel.exchanges_awaiting_delete_ok.push(self)
      end

      self
    end # delete(if_unused = false, nowait = false)


    # @group Exchange to Exchange Bindings

    # This method binds a source exchange to a destination exchange. Messages
    # sent to the source exchange are forwarded to the destination exchange, provided
    # the message routing key matches the routing key specified when binding the
    # exchanges.
    #
    # A valid exchange name (or reference) must be passed as the first
    # parameter.
    # @example Binding two source exchanges to a destination exchange
    #
    #  ch          = AMQP::Channel.new(connection)
    #  source1     = ch.fanout('backlog-events-datacenter-1')
    #  source2     = ch.fanout('backlog-events-datacenter-2')
    #  destination = ch.fanout('baklog-events')
    #  destination.bind(source1).bind(source2)
    #
    #
    # @param [Exchange] Exchange to bind to. May also be a string or any object that responds to #name.
    #
    # @option opts [String] :routing_key   Specifies the routing key for the binding. The routing key is
    #                                      used for routing messages depending on the exchange configuration.
    #                                      Not all exchanges use a routing key! Refer to the specific
    #                                      exchange documentation.
    #
    # @option opts [Hash] :arguments (nil)  A hash of optional arguments with the declaration. Headers exchange type uses these metadata
    #                                       attributes for routing matching.
    #                                       In addition, brokers may implement AMQP extensions using x-prefixed declaration arguments.
    #
    # @option opts [Boolean] :nowait (true)  If set, the server will not respond to the method. The client should
    #                                       not wait for a reply method.  If the server could not complete the
    #                                       method it will raise a channel or connection exception.
    # @return [Exchange] Self
    #
    #
    # @yield [] Since exchange.bind-ok carries no attributes, no parameters are yielded to the block.
    #

    # @api public
    def bind(source, opts = {}, &block)
      source = source.name if source.respond_to?(:name)
      routing_key = opts[:key] || opts[:routing_key] || AMQ::Protocol::EMPTY_STRING
      arguments = opts[:arguments] || {}
      nowait = opts[:nowait] || block.nil?
      @channel.once_open do
        @connection.send_frame(AMQ::Protocol::Exchange::Bind.encode(@channel.id, @name, source, routing_key, nowait, arguments))
        unless nowait
          self.define_callback(:bind, &block)
          @channel.exchanges_awaiting_bind_ok.push(self)
        end
      end
      self
    end

    # This method unbinds a source exchange from a previously bound destination exchange.
    #
    # A valid exchange name (or reference) must be passed as the first
    # parameter.
    # @example Binding and unbinding two exchanges
    #
    #  ch          = AMQP::Channel.new(connection)
    #  source      = ch.fanout('backlog-events')
    #  destination = ch.fanout('backlog-events-copy')
    #  destination.bind(source)
    #  ...
    #  destination.unbind(source)
    #
    #
    # @param [Exchange] Exchange to bind to. May also be a string or any object that responds to #name.
    #
    # @option opts [String] :routing_key   Specifies the routing key for the binding. The routing key is
    #                                      used for routing messages depending on the exchange configuration.
    #                                      Not all exchanges use a routing key! Refer to the specific
    #                                      exchange documentation.
    #
    # @option opts [Hash] :arguments (nil)  A hash of optional arguments with the declaration. Headers exchange type uses these metadata
    #                                       attributes for routing matching.
    #                                       In addition, brokers may implement AMQP extensions using x-prefixed declaration arguments.
    #
    # @option opts [Boolean] :nowait (true)  If set, the server will not respond to the method. The client should
    #                                       not wait for a reply method.  If the server could not complete the
    #                                       method it will raise a channel or connection exception.
    # @return [Exchange] Self
    #
    #
    # @yield [] Since exchange.unbind-ok carries no attributes, no parameters are yielded to the block.
    #

    # @api public
    def unbind(source, opts = {}, &block)
      source = source.name if source.respond_to?(:name)
      routing_key = opts[:key] || opts[:routing_key] || AMQ::Protocol::EMPTY_STRING
      arguments = opts[:arguments] || {}
      nowait = opts[:nowait] || block.nil?
      @channel.once_open do
        @connection.send_frame(AMQ::Protocol::Exchange::Unbind.encode(@channel.id, @name, source, routing_key, nowait, arguments))
        unless nowait
          self.define_callback(:unbind, &block)
          @channel.exchanges_awaiting_unbind_ok.push(self)
        end
      end
      self
    end

    # @endgroup

    # @group Publishing Messages

    # @api public
    def basic_publish(payload, routing_key = AMQ::Protocol::EMPTY_STRING, user_headers = {}, mandatory = false)
      headers = { :priority => 0, :delivery_mode => 2, :content_type => "application/octet-stream" }.merge(user_headers)
      @connection.send_frameset(AMQ::Protocol::Basic::Publish.encode(@channel.id, payload, headers, @name, routing_key, mandatory, false, @connection.frame_max), @channel)

      # publisher confirms support. MK.
      @channel.exec_callback(:after_publish)
      self
    end


    # @api public
    def on_return(&block)
      self.redefine_callback(:return, &block)

      self
    end # on_return(&block)

    # @endgroup



    # @group Error Handling and Recovery


    # Defines a callback that will be executed after TCP connection is interrupted (typically because of a network failure).
    # Only one callback can be defined (the one defined last replaces previously added ones).
    #
    # @api public
    def on_connection_interruption(&block)
      self.redefine_callback(:after_connection_interruption, &block)
    end # on_connection_interruption(&block)
    alias after_connection_interruption on_connection_interruption

    # @private
    def handle_connection_interruption(method = nil)
      self.exec_callback_yielding_self(:after_connection_interruption)
    end # handle_connection_interruption



    # Defines a callback that will be executed after TCP connection is recovered after a network failure
    # but before AMQP connection is re-opened.
    # Only one callback can be defined (the one defined last replaces previously added ones).
    #
    # @api public
    def before_recovery(&block)
      self.redefine_callback(:before_recovery, &block)
    end # before_recovery(&block)

    # @private
    def run_before_recovery_callbacks
      self.exec_callback_yielding_self(:before_recovery)
    end


    # Defines a callback that will be executed when AMQP connection is recovered after a network failure..
    # Only one callback can be defined (the one defined last replaces previously added ones).
    #
    # @api public
    def on_recovery(&block)
      self.redefine_callback(:after_recovery, &block)
    end # on_recovery(&block)
    alias after_recovery on_recovery

    # @private
    def run_after_recovery_callbacks
      self.exec_callback_yielding_self(:after_recovery)
    end


    # Called by associated connection object when AMQP connection has been re-established
    # (for example, after a network failure).
    #
    # @api plugin
    def auto_recover
      self.redeclare unless predefined?
    end # auto_recover

    # @endgroup



    #
    # Implementation
    #


    def handle_declare_ok(method)
      @channel.register_exchange(self)

      self.exec_callback_once_yielding_self(:declare, method)
    end

    def handle_bind_ok(method)
      self.exec_callback_once(:bind, method)
    end

    def handle_unbind_ok(method)
      self.exec_callback_once(:unbind, method)
    end

    def handle_delete_ok(method)
      self.exec_callback_once(:delete, method)
    end


    self.handle(AMQ::Protocol::Exchange::DeclareOk) do |connection, frame|
      method   = frame.decode_payload
      channel  = connection.channels[frame.channel]
      exchange = channel.exchanges_awaiting_declare_ok.shift

      exchange.handle_declare_ok(method)
    end # handle

    self.handle(AMQ::Protocol::Exchange::BindOk) do |connection, frame|
      method   = frame.decode_payload
      channel  = connection.channels[frame.channel]
      exchange = channel.exchanges_awaiting_bind_ok.shift

      exchange.handle_bind_ok(method)
    end # handle

    self.handle(AMQ::Protocol::Exchange::UnbindOk) do |connection, frame|
      method   = frame.decode_payload
      channel  = connection.channels[frame.channel]
      exchange = channel.exchanges_awaiting_unbind_ok.shift

      exchange.handle_unbind_ok(method)
    end # handle

    self.handle(AMQ::Protocol::Exchange::DeleteOk) do |connection, frame|
      channel  = connection.channels[frame.channel]
      exchange = channel.exchanges_awaiting_delete_ok.shift
      exchange.handle_delete_ok(frame.decode_payload)
    end # handle


    self.handle(AMQ::Protocol::Basic::Return) do |connection, frame, content_frames|
      channel  = connection.channels[frame.channel]
      method   = frame.decode_payload
      exchange = channel.find_exchange(method.exchange)

      header   = content_frames.shift
      body     = content_frames.map { |frame| frame.payload }.join

      exchange.exec_callback(:return, method, header, body)
    end



    protected

    # @private
    def self.add_default_options(type, name, opts, block)
      { :exchange => name, :type => type, :nowait => block.nil?, :internal => false }.merge(opts)
    end
  end # Exchange
end # AMQP
