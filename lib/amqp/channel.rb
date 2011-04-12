# encoding: utf-8

require "amqp/collection"
require "amqp/exchange"
require "amqp/queue"

module AMQP
  # To quote {AMQP 0.9.1 specification http://bit.ly/hw2ELX}:
  #
  # AMQP is a multi-channelled protocol. Channels provide a way to multiplex
  # a heavyweight TCP/IP connection into several light weight connections.
  # This makes the protocol more “firewall friendly” since port usage is predictable.
  # It also means that traffic shaping and other network QoS features can be easily employed.
  # Channels are independent of each other and can perform different functions simultaneously
  # with other channels, the available bandwidth being shared between the concurrent activities.
  #
  #
  # h2. Key methods
  #
  # Key methods of Channel class are
  #
  # * {Channel#queue}
  # * {Channel#default_exchange}
  # * {Channel#direct}
  # * {Channel#fanout}
  # * {Channel#topic}
  # * {Channel#close}
  #
  # Channel provides a number of convenience methods that instantiate queues and exchanges
  # of various types associated with this channel:
  #
  # * {Channel#queue}
  # * {Channel#default_exchange}
  # * {Channel#direct}
  # * {Channel#fanout}
  # * {Channel#topic}
  #
  # Channels are opened when objects is instantiated and closed using {#close} method when application no longer
  # needs it.
  #
  # @see http://bit.ly/hw2ELX AMQP 0.9.1 specification (Section 2.2.5)
  class Channel < AMQ::Client::Channel

    #
    # API
    #

    # AMQP connection this channel is part of
    # @return [Connection]
    attr_reader :connection
    alias :conn :connection

    # Status of this channel (one of: :opening, :closing, :open, :closed)
    # @return [Symbol]
    attr_reader :status


    # Returns a new channel. A channel is a bidirectional virtual
    # connection between the client and the AMQP server. Elsewhere in the
    # library the channel is referred to in parameter lists as +mq+.
    #
    # Optionally takes the result from calling AMQP::connect.
    #
    # Rarely called directly by client code. This is implicitly called
    # by most instance methods. See #method_missing.
    #
    #  EM.run do
    #    channel = AMQP::Channel.new
    #  end
    #
    #  EM.run do
    #    channel = AMQP::Channel.new AMQP::connect
    #  end
    #
    # @api public
    def initialize(connection = nil, id = self.class.next_channel_id, &block)
      raise 'AMQP can only be used from within EM.run {}' unless EM.reactor_running?

      @connection = connection || AMQP.start

      super(@connection, id)

      @rpcs       = Hash.new

      # only send channel.open when connection is actually open. Makes it possible to
      # do c = AMQP.connect; AMQP::Channel.new(c) that is what some people do. MK.
      @connection.on_open { self.open(&block) }
    end

    # Defines, intializes and returns a direct Exchange instance.
    #
    # Learn more about direct exchanges in {Exchange Exchange class documentation}.
    #
    #
    # @param [String] name (amq.direct) Exchange name.
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
    # @option opts [Boolean] :internal (default false)   If set, the exchange may not be used directly by publishers, but
    #                                                    only when bound to other exchanges. Internal exchanges are used to
    #                                                    construct wiring that is not visible to applications. This is a RabbitMQ-specific
    #                                                    extension.
    #
    # @option opts [Boolean] :nowait (true)              If set, the server will not respond to the method. The client should
    #                                                    not wait for a reply method.  If the server could not complete the
    #                                                    method it will raise a channel or connection exception.
    #
    #
    # @raise [AMQP::Error] Raised when exchange is redeclared with parameters different from original declaration.
    # @raise [AMQP::Error] Raised when exchange is declared with  :passive => true and the exchange does not exist.
    #
    #
    # @example Using default pre-declared direct exchange
    #
    #    # an exchange application A will be using to publish updates
    #    # to some search index
    #    exchange = channel.direct("index.updates")
    #
    #    # In the same (or different) process declare a queue that broker will
    #    # generate name for, bind it to aforementioned exchange using method chaining
    #    queue    = channel.queue("").
    #                       # queue will be receiving messages that were published with
    #                       # :routing_key attribute value of "search.index.updates"
    #                       bind(exchange, :routing_key => "search.index.updates").
    #                       # register a callback that will be run when messages arrive
    #                       subscribe { |header, message| puts("Received #{message}") }
    #
    #    # now publish a new document contents for indexing,
    #    # message will be delivered to the queue we declared and bound on the line above
    #    exchange.publish(document.content, :routing_key => "search.index.updates")
    #
    #
    # @see Channel#default_exchange
    # @see Exchange
    # @see Exchange#initialize
    # @see http://bit.ly/hw2ELX AMQP 0.9.1 specification (Section 3.1.3.1)
    #
    # @return [Exchange]
    # @api public
    def direct(name = 'amq.direct', opts = {}, &block)
      if exchange = find_exchange(name)
        extended_opts = Exchange.add_default_options(:direct, name, opts, block)

        validate_parameters_match!(exchange, extended_opts)

        exchange
      else
        register_exchange(Exchange.new(self, :direct, name, opts, &block))
      end
    end

    # Returns exchange object with the same name as default (aka unnamed) exchange.
    # Default exchange is a direct exchange and automatically routes messages to
    # queues when routing key matches queue name exactly.
    #
    # @see Exchange
    # @see http://bit.ly/hw2ELX AMQP 0.9.1 specification (Section 2.1.2.4)
    #
    # @return [Exchange]
    # @api public
    def default_exchange
      Exchange.default(self)
    end

    # Defines, intializes and returns a fanout Exchange instance.
    #
    # Learn more about fanout exchanges in {Exchange Exchange class documentation}.
    #
    #
    # @param [String] name (amq.fanout) Exchange name.
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
    # @option opts [Boolean] :internal (default false)   If set, the exchange may not be used directly by publishers, but
    #                                                    only when bound to other exchanges. Internal exchanges are used to
    #                                                    construct wiring that is not visible to applications. This is a RabbitMQ-specific
    #                                                    extension.
    #
    # @option opts [Boolean] :nowait (true)              If set, the server will not respond to the method. The client should
    #                                                    not wait for a reply method.  If the server could not complete the
    #                                                    method it will raise a channel or connection exception.
    #
    #
    # @raise [AMQP::Error] Raised when exchange is redeclared with parameters different from original declaration.
    # @raise [AMQP::Error] Raised when exchange is declared with  :passive => true and the exchange does not exist.
    #
    #
    # @example Using fanout exchange to deliver messages to multiple consumers
    #
    #   # open up a channel
    #   # declare a fanout exchange
    #   # declare 3 queues, binds them
    #   # publish a message
    #
    # @see Exchange
    # @see Exchange#initialize
    # @see Channel#default_exchange
    # @see http://bit.ly/hw2ELX AMQP 0.9.1 specification (Section 3.1.3.2)
    #
    # @return [Exchange]
    # @api public
    def fanout(name = 'amq.fanout', opts = {}, &block)
      if exchange = find_exchange(name)
        extended_opts = Exchange.add_default_options(:fanout, name, opts, block)

        validate_parameters_match!(exchange, extended_opts)

        exchange
      else
        register_exchange(Exchange.new(self, :fanout, name, opts, &block))
      end
    end


    # Defines, intializes and returns a topic Exchange instance.
    #
    # Learn more about topic exchanges in {Exchange Exchange class documentation}.
    #
    # @param [String] name (amq.topic) Exchange name.
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
    # @option opts [Boolean] :internal (default false)   If set, the exchange may not be used directly by publishers, but
    #                                                    only when bound to other exchanges. Internal exchanges are used to
    #                                                    construct wiring that is not visible to applications. This is a RabbitMQ-specific
    #                                                    extension.
    #
    # @option opts [Boolean] :nowait (true)              If set, the server will not respond to the method. The client should
    #                                                    not wait for a reply method.  If the server could not complete the
    #                                                    method it will raise a channel or connection exception.
    #
    #
    # @raise [AMQP::Error] Raised when exchange is redeclared with parameters different from original declaration.
    # @raise [AMQP::Error] Raised when exchange is declared with  :passive => true and the exchange does not exist.
    #
    #
    # @example Using fanout exchange to deliver messages to multiple consumers
    #
    #   # open up a channel
    #   # declare a topic exchange
    #   # declare 3 queues, binds them
    #   # publish a message
    #
    #
    # @see Exchange
    # @see Exchange#initialize
    # @see Channel#default_exchange
    # @see http://bit.ly/hw2ELX AMQP 0.9.1 specification (Section 3.1.3.3)
    #
    # @return [Exchange]
    # @api public
    def topic(name = 'amq.topic', opts = {}, &block)
      if exchange = find_exchange(name)
        extended_opts = Exchange.add_default_options(:topic, name, opts, block)

        validate_parameters_match!(exchange, extended_opts)

        exchange
      else
        register_exchange(Exchange.new(self, :topic, name, opts, &block))
      end
    end


    # Defines, intializes and returns a headers Exchange instance.
    #
    # Learn more about headers exchanges in {Exchange Exchange class documentation}.
    #
    # @param [String] name (amq.match) Exchange name.
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
    # @option opts [Boolean] :internal (default false)   If set, the exchange may not be used directly by publishers, but
    #                                                    only when bound to other exchanges. Internal exchanges are used to
    #                                                    construct wiring that is not visible to applications. This is a RabbitMQ-specific
    #                                                    extension.
    #
    # @option opts [Boolean] :nowait (true)              If set, the server will not respond to the method. The client should
    #                                                    not wait for a reply method.  If the server could not complete the
    #                                                    method it will raise a channel or connection exception.
    #
    #
    # @raise [AMQP::Error] Raised when exchange is redeclared with parameters different from original declaration.
    # @raise [AMQP::Error] Raised when exchange is declared with  :passive => true and the exchange does not exist.
    #
    #
    # @example Using fanout exchange to deliver messages to multiple consumers
    #
    #   # TODO
    #
    #
    # @see Exchange
    # @see Exchange#initialize
    # @see Channel#default_exchange
    # @see http://bit.ly/hw2ELX AMQP 0.9.1 specification (Section 3.1.3.3)
    #
    # @return [Exchange]
    # @api public
    def headers(name = 'amq.match', opts = {}, &block)
      if exchange = find_exchange(name)
        extended_opts = Exchange.add_default_options(:headers, name, opts, block)

        validate_parameters_match!(exchange, extended_opts)

        exchange
      else
        register_exchange(Exchange.new(self, :headers, name, opts, &block))
      end
    end


    # Declares and retursn a Queue instance.
    #
    # Like an Exchange, queue names starting with 'amq.' are reserved for
    # internal use. Attempts to declare queue with names that violate this
    # requirement will raise AMQP::Error.
    #
    # To make broker generate queue name for you (a classic example is exclusive
    # queues that are only used for a short period of time), pass empty string
    # as name value. Then queue will get it's name as soon as broker's response
    # (queue.declare-ok) arrives.
    #
    # @option opts [Boolean] :passive (false)  If set, the server will not create the exchange if it does not
    #                                          already exist. The client can use this to check whether an exchange
    #                                          exists without modifying the server state.
    #
    # @option opts [Boolean] :durable (false)  If set when creating a new exchange, the exchange will be marked as
    #                                          durable. Durable exchanges and their bindings are recreated upon a server
    #                                          restart (information about them is persisted). Non-durable (transient) exchanges
    #                                          do not survive if/when a server restarts (information about them is stored exclusively
    #                                          in RAM). Any remaining messages in the queue will be purged when the queue
    #                                          is deleted regardless of the message's persistence setting.
    #
    #
    # @option opts [Boolean] :auto_delete  (false)  If set, the exchange is deleted when all queues have finished
    #                                               using it. The server waits for a short period of time before
    #                                               determining the exchange is unused to give time to the client code
    #                                               to bind a queue to it.
    #
    # @option opts [Boolean] :exclusive (false)  Exclusive queues may only be used by a single connection.
    #                                                    Exclusivity also implies that queue is automatically deleted when connection
    #                                                    is closed. Only one consumer is allowed to remove messages from exclusive queue.
    #
    # @option opts [Boolean] :nowait (true)              If set, the server will not respond to the method. The client should
    #                                                    not wait for a reply method.  If the server could not complete the
    #                                                    method it will raise a channel or connection exception.
    #
    #
    # @raise [AMQP::Error] Raised when queue is redeclared with parameters different from original declaration.
    # @raise [AMQP::Error] Raised when queue is declared with :passive => true and the queue does not exist.
    # @raise [AMQP::Error] Raised when queue is declared with :exclusive => true and queue with that name already exist.
    #
    # @see Queue
    # @see Queue#initialize
    # @see http://bit.ly/hw2ELX AMQP 0.9.1 specification (Section 2.1.4)
    #
    # @return [Queue]
    # @api public
    def queue(name, opts = {}, &block)
      if name && !name.empty? && (queue = find_queue(name))
        extended_opts = Queue.add_default_options(name, opts, block)

        validate_parameters_match!(queue, extended_opts)

        queue
      else
        queue = if block.nil?
                  Queue.new(self, name, opts)
                else
                  shim = Proc.new { |method|
            queue = find_queue(method.queue)
            if block.arity == 1
              block.call(queue)
            else
              block.call(queue, method.consumer_count, method.message_count)
            end
          }
                  Queue.new(self, name, opts, &shim)
                end

        register_queue(queue)
      end
    end

    # Returns true if channel is not closed.
    # @return [Boolean]
    # @api public
    def open?
      self.status == :opened || self.status == :opening
    end # open?


    def queue!(name, opts = {}, &block)
      # TODO
      raise NotImplementedError.new
    end


    # Instantiates and returns an RPC instance associated with this channel.
    #
    # The optional object may be a class name, module name or object
    # instance. When given a class or module name, the object is instantiated
    # during this setup. The passed queue is automatically subscribed to so
    # it passes all messages (and their arguments) to the object.
    #
    # Marshalling and unmarshalling the objects is handled internally. This
    # marshalling is subject to the same restrictions as defined in the
    # Marshal[http://ruby-doc.org/core/classes/Marshal.html] standard
    # library. See that documentation for further reference.
    #
    # When the optional object is not passed, the returned rpc reference is
    # used to send messages and arguments to the queue. See #method_missing
    # which does all of the heavy lifting with the proxy. Some client
    # elsewhere must call this method *with* the optional block so that
    # there is a valid destination. Failure to do so will just enqueue
    # marshalled messages that are never consumed.
    #
    # @example Use of RPC
    #
    #   # TODO
    #
    #
    # @param [String, Queue] Queue to be used by RPC server.
    # @return [RPC]
    # @api public
    def rpc(name, obj = nil)
      RPC.new(self, name, obj)
    end


    # Define a callback to be run on channel-level exception.
    #
    # @param [String] msg Error message
    #
    # @api public
    def self.error(msg = nil, &block)
      # TODO
      raise NotImplementedError.new
    end

    # @param [Fixnum] size
    # @param [Boolean] global (false)
    #
    # @return [Channel] self
    #
    # @api public
    def prefetch(size, global = false, &block)
      # RabbitMQ as of 2.3.1 does not support prefetch_size.
      self.qos(0, size, global, &block)

      self
    end



    # Returns a hash of all rpc proxy objects.
    #
    # Most of the time, this method is not
    # called by application code.
    # @api plugin
    def rpcs
      @rpcs.values
    end



    #
    # Implementation
    #


    # Resets channel state (for example, list of registered queue objects and so on).
    #
    # Most of the time, this method is not
    # called by application code.
    #
    # @private
    # @api plugin
    def reset
      # TODO
      raise NotImplementedError.new
    end

    # @private
    # @api private
    def self.channel_id_mutex
      @channel_id_mutex ||= Mutex.new
    end

    # @return [Fixnum]
    # @private
    # @api private
    def self.next_channel_id
      channel_id_mutex.synchronize do
        @last_channel_id ||= 0
        @last_channel_id += 1

        @last_channel_id
      end
    end

    # @private
    # @api plugin
    def register_rpc(rpc)
      raise ArgumentError, "argument is nil!" unless rpc

      @rpcs[rpc.name] = rpc
    end # register_rpc(rpc)

    # @private
    # @api plugin
    def find_rpc(name)
      @rpcs[name]
    end


    protected

    def validate_parameters_match!(entity, parameters)
      unless entity.opts == parameters || parameters[:passive]
        raise AMQP::IncompatibleOptionsError.new(entity.name, entity.opts, parameters)
      end
    end # validate_parameters_match!(entity, parameters)
  end # Channel
end # AMQP
