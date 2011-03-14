# encoding: utf-8

module AMQP
  # The top-level class for building AMQP clients. This class contains several
  # convenience methods for working with queues and exchanges. Many calls
  # delegate/forward to subclasses, but this is the preferred API. The subclass
  # API is subject to change while this high-level API will likely remain
  # unchanged as the library evolves. All code examples will be written using
  # the AMQP API.
  #
  # Below is a somewhat complex example that demonstrates several capabilities
  # of the library. The example starts a clock using a +fanout+ exchange which
  # is used for 1 to many communications. Each consumer generates a queue to
  # receive messages and do some operation (in this case, print the time).
  # One consumer prints messages every second while the second consumer prints
  # messages every 2 seconds. After 5 seconds has elapsed, the 1 second
  # consumer is deleted.
  #
  # Of interest is the relationship of EventMachine to the process. All AMQP
  # operations must occur within the context of an EM.run block. We start
  # EventMachine in its own thread with an empty block; all subsequent calls
  # to the AMQP API add their blocks to the EM.run block. This demonstrates how
  # the library could be used to build up and tear down communications outside
  # the context of an EventMachine block and/or integrate the library with
  # other synchronous operations. See the EventMachine documentation for
  # more information.
  #
  #   require 'rubygems'
  #   require 'mq'
  #
  #   thr = Thread.new { EM.run }
  #
  #   # turns on extreme logging
  #   #AMQP.logging = true
  #
  #   def log *args
  #     p args
  #   end
  #
  #   def publisher
  #     clock = AMQP::Channel.fanout('clock')
  #     EM.add_periodic_timer(1) do
  #       puts
  #
  #       log :publishing, time = Time.now
  #       clock.publish(Marshal.dump(time))
  #     end
  #   end
  #
  #   def one_second_consumer
  #     AMQP::Channel.queue('every second').bind(AMQP::Channel.fanout('clock')).subscribe do |time|
  #       log 'every second', :received, Marshal.load(time)
  #     end
  #   end
  #
  #   def two_second_consumer
  #     AMQP::Channel.queue('every 2 seconds').bind('clock').subscribe do |time|
  #       time = Marshal.load(time)
  #       log 'every 2 seconds', :received, time if time.sec % 2 == 0
  #     end
  #   end
  #
  #   def delete_one_second
  #     EM.add_timer(5) do
  #       # delete the 'every second' queue
  #       log 'Deleting [every second] queue'
  #       AMQP::Channel.queue('every second').delete
  #     end
  #   end
  #
  #   publisher
  #   one_second_consumer
  #   two_second_consumer
  #   delete_one_second
  #   thr.join
  #
  #  __END__
  #
  #  [:publishing, Tue Jan 06 22:46:14 -0600 2009]
  #  ["every second", :received, Tue Jan 06 22:46:14 -0600 2009]
  #  ["every 2 seconds", :received, Tue Jan 06 22:46:14 -0600 2009]
  #
  #  [:publishing, Tue Jan 06 22:46:16 -0600 2009]
  #  ["every second", :received, Tue Jan 06 22:46:16 -0600 2009]
  #  ["every 2 seconds", :received, Tue Jan 06 22:46:16 -0600 2009]
  #
  #  [:publishing, Tue Jan 06 22:46:17 -0600 2009]
  #  ["every second", :received, Tue Jan 06 22:46:17 -0600 2009]
  #
  #  [:publishing, Tue Jan 06 22:46:18 -0600 2009]
  #  ["every second", :received, Tue Jan 06 22:46:18 -0600 2009]
  #  ["every 2 seconds", :received, Tue Jan 06 22:46:18 -0600 2009]
  #  ["Deleting [every second] queue"]
  #
  #  [:publishing, Tue Jan 06 22:46:19 -0600 2009]
  #
  #  [:publishing, Tue Jan 06 22:46:20 -0600 2009]
  #  ["every 2 seconds", :received, Tue Jan 06 22:46:20 -0600 2009]
  #
  class Channel < AMQ::Client::Channel

    #
    # API
    #

    attr_reader :channel, :connection, :status
    alias :conn :connection


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
    def initialize(connection = nil, id = self.class.next_channel_id)
      raise 'AMQP can only be used from within EM.run {}' unless EM.reactor_running?

      @connection = connection || AMQP.start
      super(@connection, id)
    end



    # Defines, intializes and returns an Exchange to act as an ingress
    # point for all published messages.
    #
    # == Direct
    # A direct exchange is useful for 1:1 communication between a publisher and
    # subscriber. Messages are routed to the queue with a binding that shares
    # the same name as the exchange. Alternately, the messages are routed to
    # the bound queue that shares the same name as the routing key used for
    # defining the exchange. This exchange type does not honor the +:key+ option
    # when defining a new instance with a name. It _will_ honor the +:key+ option
    # if the exchange name is the empty string.
    # Allocating this exchange without a name _or_ with the empty string
    # will use the internal 'amq.direct' exchange.
    #
    # Any published message, regardless of its persistence setting, is thrown
    # away by the exchange when there are no queues bound to it.
    #
    #  # exchange is named 'foo'
    #  exchange = AMQP::Channel.direct('foo')
    #
    #  # or, the exchange can use the default name (amq.direct) and perform
    #  # routing comparisons using the :key
    #  exchange = AMQP::Channel.direct("", :key => 'foo')
    #  exchange.publish('some data') # will be delivered to queue bound to 'foo'
    #
    #  queue = AMQP::Channel.queue('foo')
    #  # can receive data since the queue name and the exchange key match exactly
    #  queue.pop { |data| puts "received data [#{data}]" }
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
    # A transient exchange (the default) is stored in memory-only. The
    # exchange and all bindings will be lost on a server restart.
    # It makes no sense to publish a persistent message to a transient
    # exchange.
    #
    # Durable exchanges and their bindings are recreated upon a server
    # restart. Any published messages not routed to a bound queue are lost.
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
    # == Exceptions
    # Doing any of these activities are illegal and will raise AMQP::Error.
    # * redeclare an already-declared exchange to a different type
    # * :passive => true and the exchange does not exist (NOT_FOUND)
    #
    # @api public    
    def direct(name = 'amq.direct', opts = {}, &block)
      # TODO
    end


    # Defines, intializes and returns an Exchange to act as an ingress
    # point for all published messages.
    #
    # == Fanout
    # A fanout exchange is useful for 1:N communication where one publisher
    # feeds multiple subscribers. Like direct exchanges, messages published
    # to a fanout exchange are delivered to queues whose name matches the
    # exchange name (or are bound to that exchange name). Each queue gets
    # its own copy of the message.
    #
    # Any published message, regardless of its persistence setting, is thrown
    # away by the exchange when there are no queues bound to it.
    #
    # Like the direct exchange type, this exchange type does not honor the
    # +:key+ option when defining a new instance with a name. It _will_ honor
    # the +:key+ option if the exchange name is the empty string.
    # Allocating this exchange without a name _or_ with the empty string
    # will use the internal 'amq.fanout' exchange.
    #
    #  EM.run do
    #    clock = AMQP::Channel.fanout('clock')
    #    EM.add_periodic_timer(1) do
    #      puts "\npublishing #{time = Time.now}"
    #      clock.publish(Marshal.dump(time))
    #    end
    #
    #    amq = AMQP::Channel.queue('every second')
    #    amq.bind(AMQP::Channel.fanout('clock')).subscribe do |time|
    #      puts "every second received #{Marshal.load(time)}"
    #    end
    #
    #    # note the string passed to #bind
    #    AMQP::Channel.queue('every 5 seconds').bind('clock').subscribe do |time|
    #      time = Marshal.load(time)
    #      puts "every 5 seconds received #{time}" if time.strftime('%S').to_i%5 == 0
    #    end
    #  end
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
    # A transient exchange (the default) is stored in memory-only. The
    # exchange and all bindings will be lost on a server restart.
    # It makes no sense to publish a persistent message to a transient
    # exchange.
    #
    # Durable exchanges and their bindings are recreated upon a server
    # restart. Any published messages not routed to a bound queue are lost.
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
    # == Exceptions
    # Doing any of these activities are illegal and will raise AMQP::Error.
    # * redeclare an already-declared exchange to a different type
    # * :passive => true and the exchange does not exist (NOT_FOUND)
    #
    # @api public
    def fanout(name = 'amq.fanout', opts = {}, &block)
      # TODO
    end


    # Defines, intializes and returns an Exchange to act as an ingress
    # point for all published messages.
    #
    # == Topic
    # A topic exchange allows for messages to be published to an exchange
    # tagged with a specific routing key. The Exchange uses the routing key
    # to determine which queues to deliver the message. Wildcard matching
    # is allowed. The topic must be declared using dot notation to separate
    # each subtopic.
    #
    # This is the only exchange type to honor the +key+ hash key for all
    # cases.
    #
    # Any published message, regardless of its persistence setting, is thrown
    # away by the exchange when there are no queues bound to it.
    #
    # As part of the AMQP standard, each server _should_ predeclare a topic
    # exchange called 'amq.topic' (this is not required by the standard).
    # Allocating this exchange without a name _or_ with the empty string
    # will use the internal 'amq.topic' exchange.
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
    #    exch = AMQP::Channel.topic("stocks")
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
    # A transient exchange (the default) is stored in memory-only. The
    # exchange and all bindings will be lost on a server restart.
    # It makes no sense to publish a persistent message to a transient
    # exchange.
    #
    # Durable exchanges and their bindings are recreated upon a server
    # restart. Any published messages not routed to a bound queue are lost.
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
    # == Exceptions
    # Doing any of these activities are illegal and will raise AMQP::Error.
    # * redeclare an already-declared exchange to a different type
    # * :passive => true and the exchange does not exist (NOT_FOUND)
    #
    # @api public
    def topic(name = 'amq.topic', opts = {}, &block)
      # TODO
    end



    # Defines, intializes and returns an Exchange to act as an ingress
    # point for all published messages.
    #
    # == Headers
    # A headers exchange allows for messages to be published to an exchange
    #
    # Any published message, regardless of its persistence setting, is thrown
    # away by the exchange when there are no queues bound to it.
    #
    # As part of the AMQP standard, each server _should_ predeclare a headers
    # exchange called 'amq.match' (this is not required by the standard).
    # Allocating this exchange without a name _or_ with the empty string
    # will use the internal 'amq.match' exchange.
    #
    # TODO: The classic example is ...
    #
    # When publishing data to the exchange, bound queues subscribing to the
    # exchange indicate which data interests them by passing arguments
    # for matching against the headers in published messages. The
    # form of the matching can be controlled by the 'x-match' argument, which
    # may be 'any' or 'all'. If unspecified (in RabbitMQ at least), it defaults
    # to "all".
    #
    # A value of 'all' for 'x-match' implies that all values must match (i.e.
    # it does an AND of the headers ), while a value of 'any' implies that
    # at least one should match (ie. it does an OR).
    #
    # TODO: document behavior when either the binding or the message is missing
    #       a header present in the other
    #
    # TODO: insert example
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
    # A transient exchange (the default) is stored in memory-only. The
    # exchange and all bindings will be lost on a server restart.
    # It makes no sense to publish a persistent message to a transient
    # exchange.
    #
    # Durable exchanges and their bindings are recreated upon a server
    # restart. Any published messages not routed to a bound queue are lost.
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
    # == Exceptions
    # Doing any of these activities are illegal and will raise AMQP::Error.
    # * redeclare an already-declared exchange to a different type
    # * :passive => true and the exchange does not exist (NOT_FOUND)
    # * using a value other than "any" or "all" for "x-match"
    #
    # @api public
    def headers(name = 'amq.match', opts = {}, &block)
      # TODO
    end


    # Queues store and forward messages.  Queues can be configured in the server
    # or created at runtime.  Queues must be attached to at least one exchange
    # in order to receive messages from publishers.
    #
    # Like an Exchange, queue names starting with 'amq.' are reserved for
    # internal use. Attempts to create queue names in violation of this
    # reservation will raise AMQP::Error (ACCESS_REFUSED).
    #
    # It is not supported to create a queue without a name; some string
    # (even the empty string) must be passed in the +name+ parameter.
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
    # Again, note the durability property on a queue has no influence on
    # the persistence of published messages. A durable queue containing
    # transient messages will flush those messages on a restart.
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
    # Any remaining messages in the queue will be purged when the queue
    # is deleted regardless of the message's persistence setting.
    #
    # * :nowait => true | false (default true)
    # If set, the server will not respond to the method. The client should
    # not wait for a reply method.  If the server could not complete the
    # method it will raise a channel or connection exception.
    #
    # @api public
    def queue(name, opts = {}, &block)
      # TODO      
    end


    def queue!(name, opts = {}, &block)
      # TODO
    end


    # Takes a channel, queue and optional object.
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
    #  EM.run do
    #    server = AMQP::Channel.new.rpc('hash table node', Hash)
    #
    #    client = AMQP::Channel.new.rpc('hash table node')
    #    client[:now] = Time.now
    #    client[:one] = 1
    #
    #    client.values do |res|
    #      p 'client', :values => res
    #    end
    #
    #    client.keys do |res|
    #      p 'client', :keys => res
    #      EM.stop_event_loop
    #    end
    #  end
    #
    # @api public
    def rpc(name, obj = nil)
    end


    def close(&block)
    end


    # Define a message and callback block to be executed on all
    # errors.
    #
    # @api public
    def self.error(msg = nil, &block)
      # TODO
    end

    # @api public
    def prefetch(size)
      # TODO
    end


    # Asks the broker to redeliver all unacknowledged messages on this
    # channel.
    #
    # * requeue (default false)
    # If this parameter is false, the message will be redelivered to the original recipient.
    # If this flag is true, the server will attempt to requeue the message, potentially then
    # delivering it to an alternative subscriber.
    #
    # @api public
    def recover(requeue = false)
      # TODO
    end


    # Returns a hash of all the exchange proxy objects.
    #
    # Most of the time, this method is not
    # called by application code.
    # @api plugin
    def exchanges
      # TODO
    end

    # Returns a hash of all the queue proxy objects.
    #
    # Most of the time, this method is not
    # called by application code.
    # @api plugin
    def queues
      # TODO      
    end

    # Returns a hash of all rpc proxy objects.
    #
    # Most of the time, this method is not
    # called by application code.
    # @api plugin
    def rpcs
      # TODO      
    end

    # Queue objects keyed on their consumer tags.
    #
    # Most of the time, this method is not
    # called by application code.
    # @api plugin
    def consumers
      # TODO
    end

    # Resets channel state (for example, list of registered queue objects and so on).
    #
    # Most of the time, this method is not
    # called by application code.
    # @api plugin
    def reset
      # TODO
    end

    def self.channel_id_mutex
      @channel_id_mutex ||= Mutex.new
    end

    def self.next_channel_id
      channel_id_mutex.synchronize do
        @last_channel_id ||= 0
        @last_channel_id += 1

        @last_channel_id
      end
    end

    protected

    def validate_parameters_match!(entity, parameters)
      unless entity.opts == parameters || parameters[:passive]
        raise AMQP::IncompatibleOptionsError.new(entity.name, entity.opts, parameters)
      end
    end # validate_parameters_match!(entity, parameters)
  end # Channel
end # AMQP
