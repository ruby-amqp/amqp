# encoding: utf-8

require "amq/client/queue"

module AMQP
  class Queue < AMQ::Client::Queue

    #
    # API
    #

    attr_reader :name, :sync_bind
    attr_accessor :opts, :on_declare, :on_bind



    # Queues store and forward messages.  Queues can be configured in the server
    # or created at runtime.  Queues must be attached to at least one exchange
    # in order to receive messages from publishers.
    #
    # Like an Exchange, queue names starting with 'amq.' are reserved for
    # internal use. Attempts to create queue names in violation of this
    # reservation will raise AMQP::Error (ACCESS_REFUSED).
    #
    # When a queue is created without a name, the server will generate a
    # unique name internally (not currently supported in this library).
    #
    # == Options
    # * :passive => true | false (default false)
    # If set, the server will not create the queue if it does not
    # already exist. The client can use this to check whether the queue
    # exists without modifying  the server state.
    #
    # * :durable => true | false (default false)
    # If set when creating a new queue, the queue will be marked as
    # durable.  Durable queues remain active when a server restarts.
    # Non-durable queues (transient queues) are purged if/when a
    # server restarts.  Note that durable queues do not necessarily
    # hold persistent messages, although it does not make sense to
    # send persistent messages to a transient queue (though it is
    # allowed).
    #
    # If the queue has already been declared, any redeclaration will
    # ignore this setting. A queue may only be declared durable the
    # first time when it is created.
    #
    # * :exclusive => true | false (default false)
    # Exclusive queues may only be consumed from by the current connection.
    # Setting the 'exclusive' flag always implies 'auto-delete'. Only a
    # single consumer is allowed to remove messages from this queue.
    #
    # The default is a shared queue. Multiple clients may consume messages
    # from this queue.
    #
    # Attempting to redeclare an already-declared queue as :exclusive => true
    # will raise AMQP::Error.
    #
    # * :auto_delete = true | false (default false)
    # If set, the queue is deleted when all consumers have finished
    # using it. Last consumer can be cancelled either explicitly or because
    # its channel is closed. If there was no consumer ever on the queue, it
    # won't be deleted.
    #
    # The server waits for a short period of time before
    # determining the queue is unused to give time to the client code
    # to bind a queue to it.
    #
    # If the queue has been previously declared, this option is ignored
    # on subsequent declarations.
    #
    # * :nowait => true | false (default true)
    # If set, the server will not respond to the method. The client should
    # not wait for a reply method.  If the server could not complete the
    # method it will raise a channel or connection exception.
    #
    # @api public
    def initialize(channel, name, opts = {}, &block)
      @channel  = channel
      @opts     = self.class.add_default_options(name, opts, block)
      @key      = opts[:key]
      @name     = name unless name.empty?
      @bindings = Hash.new

      if @opts[:nowait]
        @status = :finished
        block.call(self) if block
      else
        @status = :unfinished
      end

      super(channel.connection, channel, name)
      self.declare(@opts[:passive], @opts[:durable], @opts[:exclusive], @opts[:auto_delete], @opts[:nowait], nil, &block)
    end


    # This method binds a queue to an exchange.  Until a queue is
    # bound it will not receive any messages.  In a classic messaging
    # model, store-and-forward queues are bound to a dest exchange
    # and subscription queues are bound to a dest_wild exchange.
    #
    # A valid exchange name (or reference) must be passed as the first
    # parameter. Both of these are valid:
    #  exch = AMQP::Channel.direct('foo exchange')
    #  queue = AMQP::Channel.queue('bar queue')
    #  queue.bind('foo.exchange') # OR
    #  queue.bind(exch)
    #
    # It is not valid to call #bind without the +exchange+ parameter.
    #
    # It is unnecessary to call #bind when the exchange name and queue
    # name match exactly (for +direct+ and +fanout+ exchanges only).
    # There is an implicit bind which will deliver the messages from
    # the exchange to the queue.
    #
    # == Options
    # * :key => 'some string'
    # Specifies the routing key for the binding.  The routing key is
    # used for routing messages depending on the exchange configuration.
    # Not all exchanges use a routing key - refer to the specific
    # exchange documentation.  If the routing key is empty and the queue
    # name is empty, the routing key will be the current queue for the
    # channel, which is the last declared queue.
    #
    # * :nowait => true | false (default true)
    # If set, the server will not respond to the method. The client should
    # not wait for a reply method.  If the server could not complete the
    # method it will raise a channel or connection exception.
    #
    # @api public
    def bind(exchange, opts = {}, &block)
      @status             = :unbound
      @sync_bind          = !opts[:nowait]
      # amq-client's Queue already does exchange.respond_to?(:name) ? exchange.name : exchange
      # for us
      exchange            = exchange
      @bindings[exchange] = opts

      # TODO: we should handle nil routing key in amq-protocol
      super(exchange, (opts[:key] || opts[:routing_key] || ""), (opts[:nowait] || block.nil?), opts[:arguments], &block)

      self
    end


    # Remove the binding between the queue and exchange. The queue will
    # not receive any more messages until it is bound to another
    # exchange.
    #
    # Due to the asynchronous nature of the protocol, it is possible for
    # "in flight" messages to be received after this call completes.
    # Those messages will be serviced by the last block used in a
    # #subscribe or #pop call.
    #
    # * :nowait => true | false (default true)
    # If set, the server will not respond to the method. The client should
    # not wait for a reply method.  If the server could not complete the
    # method it will raise a channel or connection exception.
    #
    # @api public
    def unbind(exchange, opts = {}, &block)
      super(exchange, (opts[:key] || opts[:routing_key] || AMQ::Protocol::EMPTY_STRING), opts[:arguments], &block)
    end


    # This method deletes a queue.  When a queue is deleted any pending
    # messages are sent to a dead-letter queue if this is defined in the
    # server configuration, and all consumers on the queue are cancelled.
    #
    # == Options
    # * :if_unused => true | false (default false)
    # If set, the server will only delete the queue if it has no
    # consumers. If the queue has consumers the server does does not
    # delete it but raises a channel exception instead.
    #
    # * :if_empty => true | false (default false)
    # If set, the server will only delete the queue if it has no
    # messages. If the queue is not empty the server raises a channel
    # exception.
    #
    # * :nowait => true | false (default true)
    # If set, the server will not respond to the method. The client should
    # not wait for a reply method.  If the server could not complete the
    # method it will raise a channel or connection exception.
    #
    # @api public
    def delete(opts = {}, &block)
      super(opts.fetch(:if_unused, false), opts.fetch(:if_empty, false), opts.fetch(:nowait, false), &block)

      # backwards compatibility
      nil
    end


    # Purge all messages from the queue.
    #
    # @api public
    def purge(opts = {}, &block)
      super(opts.fetch(:nowait, false), &block)

      # backwards compatibility
      nil
    end


    # This method provides a direct access to the messages in a queue
    # using a synchronous dialogue that is designed for specific types of
    # application where synchronous functionality is more important than
    # performance.
    #
    # The provided block is passed a single message each time pop is called.
    #
    #  EM.run do
    #    exchange = AMQP::Channel.direct("foo queue")
    #    EM.add_periodic_timer(1) do
    #      exchange.publish("random number #{rand(1000)}")
    #    end
    #
    #    # note that #bind is never called; it is implicit because
    #    # the exchange and queue names match
    #    queue = AMQP::Channel.queue('foo queue')
    #    queue.pop { |body| puts "received payload [#{body}]" }
    #
    #    EM.add_periodic_timer(1) { queue.pop }
    #  end
    #
    # If the block takes 2 parameters, both the +header+ and the +body+ will
    # be passed in for processing. The header object is defined by
    # AMQP::Protocol::Header.
    #
    #  EM.run do
    #    exchange = AMQP::Channel.direct("foo queue")
    #    EM.add_periodic_timer(1) do
    #      exchange.publish("random number #{rand(1000)}")
    #    end
    #
    #    queue = AMQP::Channel.queue('foo queue')
    #    queue.pop do |header, body|
    #      p header
    #      puts "received payload [#{body}]"
    #    end
    #
    #    EM.add_periodic_timer(1) { queue.pop }
    #  end
    #
    # == Options
    # * :ack => true | false (default false)
    # If this field is set to false the server does not expect acknowledgments
    # for messages.  That is, when a message is delivered to the client
    # the server automatically and silently acknowledges it on behalf
    # of the client.  This functionality increases performance but at
    # the cost of reliability.  Messages can get lost if a client dies
    # before it can deliver them to the application.
    #
    # @api public
    def pop(opts = {}, &block)
      if block
        # We have to maintain this multiple arities jazz
        # because older versions this gem are used in examples in at least 3
        # books published by O'Reilly :(. MK.
        shim = Proc.new { |method, headers, payload|
          case block.arity
          when 1 then
            block.call(payload)
          when 2 then
            h = Header.new(@channel, method, headers ? headers.decode_payload : nil)
            block.call(h, payload)
          else
            h = Header.new(@channel, method, headers ? headers.decode_payload : nil)
            block.call(h, payload, method.delivery_tag, method.redelivered, method.exchange, method.routing_key)
          end
        }

        # see AMQ::Client::Queue#get in amq-client
        self.get(!opts.fetch(:ack, false), &shim)
      else
        self.get(!opts.fetch(:ack, false))
      end
    end


    # Subscribes to asynchronous message delivery.
    #
    # The provided block is passed a single message each time the
    # exchange matches a message to this queue.
    #
    #  EM.run do
    #    exchange = AMQP::Channel.direct("foo queue")
    #    EM.add_periodic_timer(1) do
    #      exchange.publish("random number #{rand(1000)}")
    #    end
    #
    #    queue = AMQP::Channel.queue('foo queue')
    #    queue.subscribe { |body| puts "received payload [#{body}]" }
    #  end
    #
    # If the block takes 2 parameters, both the +header+ and the +body+ will
    # be passed in for processing. The header object is defined by
    # AMQP::Protocol::Header.
    #
    #  EM.run do
    #    exchange = AMQP::Channel.direct("foo queue")
    #    EM.add_periodic_timer(1) do
    #      exchange.publish("random number #{rand(1000)}")
    #    end
    #
    #    # note that #bind is never called; it is implicit because
    #    # the exchange and queue names match
    #    queue = AMQP::Channel.queue('foo queue')
    #    queue.subscribe do |header, body|
    #      p header
    #      puts "received payload [#{body}]"
    #    end
    #  end
    #
    # == Options
    # * :ack => true | false (default false)
    # If this field is set to false the server does not expect acknowledgments
    # for messages.  That is, when a message is delivered to the client
    # the server automatically and silently acknowledges it on behalf
    # of the client.  This functionality increases performance but at
    # the cost of reliability.  Messages can get lost if a client dies
    # before it can deliver them to the application.
    #
    # * :nowait => true | false (default true)
    # If set, the server will not respond to the method. The client should
    # not wait for a reply method.  If the server could not complete the
    # method it will raise a channel or connection exception.
    #
    # * :confirm => proc (default nil)
    # If set, this proc will be called when the server confirms subscription
    # to the queue with a ConsumeOk message. Setting this option will
    # automatically set :nowait => false. This is required for the server
    # to send a confirmation.
    #
    # @api public
    def subscribe(opts = {}, &block)
      raise Error, 'already subscribed to the queue' if @consumer_tag

      opts[:nowait] = false if (@on_confirm_subscribe = opts[:confirm])

      # We have to maintain this multiple arities jazz
      # because older versions this gem are used in examples in at least 3
      # books published by O'Reilly :(. MK.
      delivery_shim = Proc.new { |method, headers, payload|
        case block.arity
        when 1 then
          block.call(payload)
        when 2 then
          h = Header.new(@channel, method, headers.decode_payload)
          block.call(h, payload)
        else
          h = Header.new(@channel, method, headers.decode_payload)
          block.call(h, payload, method.consumer_tag, method.delivery_tag, method.redelivered, method.exchange, method.routing_key)
        end
      }

      self.consume(!opts[:ack], opts[:exclusive], (opts[:nowait] || block.nil?), opts[:no_local], nil, &opts[:confirm])
      self.on_delivery(&delivery_shim)

      self
    end


    # Removes the subscription from the queue and cancels the consumer.
    # New messages will not be received by the queue. This call is similar
    # in result to calling #unbind.
    #
    # Due to the asynchronous nature of the protocol, it is possible for
    # "in flight" messages to be received after this call completes.
    # Those messages will be serviced by the last block used in a
    # #subscribe or #pop call.
    #
    # Additionally, if the queue was created with _autodelete_ set to
    # true, the server will delete the queue after its wait period
    # has expired unless the queue is bound to an active exchange.
    #
    # The method accepts a block which will be executed when the
    # unsubscription request is acknowledged as complete by the server.
    #
    # * :nowait => true | false (default true)
    # If set, the server will not respond to the method. The client should
    # not wait for a reply method.  If the server could not complete the
    # method it will raise a channel or connection exception.
    #
    # @api public
    def unsubscribe(opts = {}, &block)
      # @consumer_tag is nillified for us by AMQ::Client::Queue, that is,
      # our superclass. MK.
      self.cancel(opts.fetch(:nowait, true), &block)
    end

    # Get the number of messages and consumers on a queue.
    #
    #  AMQP::Channel.queue('name').status { |num_messages, num_consumers|
    #   puts num_messages
    #  }
    #
    # @api public
    def status(opts = {}, &block)
      raise ArgumentError, "AMQP::Queue#status does not make any sense without a block" unless block

      shim = Proc.new { |declare_ok| block.call(declare_ok.message_count, declare_ok.consumer_count) }

      self.declare(true, @durable, @exclusive, @auto_delete, false, nil, &shim)
    end


    # Boolean check to see if the current queue has already subscribed
    # to messages delivery.
    #
    # Attempts to #subscribe multiple times to any exchange will raise an
    # Exception. Only a single block at a time can be associated with any
    # one queue for processing incoming messages.
    #
    # @api public
    def subscribed?
      !!@consumer_tag
    end


    # Compatibility alias for #on_declare.
    #
    # @api public
    # @deprecated
    def callback
      @on_declare
    end

    # Compatibility alias for #on_bind.
    #
    # @api public
    # @deprecated
    def bind_callback
      @on_bind
    end




    # Don't use this method. Just don't. It is a leftover from very early days and
    # it ruins the whole point of exchanges/queue separation.
    #
    # @note This method will be removed before 1.0 release
    # @deprecated
    # @api public
    def publish(data, opts = {})
      exchange.publish(data, opts)
    end

    # @api plugin
    def reset
      # TODO
      raise NotImplementedError.new
    end


    protected

    def self.add_default_options(name, opts, block)
      { :queue => name, :nowait => block.nil? }.merge(opts)
    end

    private

    # Default direct exchange that we use to publish messages directly to this queue.
    # This is a leftover from very early days and will be removed before version 1.0.
    #
    # @deprecated
    def exchange
      @exchange ||= Exchange.new(@channel, :direct, AMQ::Protocol::EMPTY_STRING, :key => name)
    end
  end # Queue
end # AMQP
