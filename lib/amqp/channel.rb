# encoding: utf-8

require "amqp/exchange"
require "amqp/queue"

module AMQP
  # h2. What are AMQP channels
  #
  # To quote {http://bit.ly/hw2ELX AMQP 0.9.1 specification}:
  #
  # AMQP is a multi-channelled protocol. Channels provide a way to multiplex
  # a heavyweight TCP/IP connection into several light weight connections.
  # This makes the protocol more “firewall friendly” since port usage is predictable.
  # It also means that traffic shaping and other network QoS features can be easily employed.
  # Channels are independent of each other and can perform different functions simultaneously
  # with other channels, the available bandwidth being shared between the concurrent activities.
  #
  # h2. Opening a channel
  #
  # *Channels are opened asynchronously*. There are two ways to do it: using a callback or pseudo-synchronous mode.
  #
  # @example Opening a channel with a callback
  #   # this assumes EventMachine reactor is running
  #   AMQP.connect("amqp://guest:guest@dev.rabbitmq.com:5672") do |client|
  #     AMQP::Channel.new(client) do |channel, open_ok|
  #       # when this block is executed, channel is open and ready for use
  #     end
  #   end
  #
  # <script src="https://gist.github.com/939480.js?file=gistfile1.rb"></script>
  #
  # Unless your application needs multiple channels, this approach is recommended. Alternatively,
  # AMQP::Channel can be instantiated without a block. Then returned channel is not immediately open,
  # however, it can be used as if it was a synchronous, blocking method:
  #
  # @example Instantiating a channel that will be open eventually
  #   # this assumes EventMachine reactor is running
  #   AMQP.connect("amqp://guest:guest@dev.rabbitmq.com:5672") do |client|
  #     channel  = AMQP::Channel.new(client)
  #     exchange = channel.default_exchange
  #
  #     # ...
  #   end
  #
  # <script src="https://gist.github.com/939482.js?file=gistfile1.rb"></script>
  #
  # Even though in the example above channel isn't immediately open, it is safe to declare exchanges using
  # it. Exchange declaration will be delayed until after channel is open. Same applies to queue declaration
  # and other operations on exchanges and queues. Library methods that rely on channel being open will be
  # enqueued and executed in a FIFO manner when broker confirms channel opening.
  # Note, however, that *this "pseudo-synchronous mode" is easy to abuse and introduce race conditions AMQP gem
  # cannot resolve for you*. AMQP is an inherently asynchronous protocol and AMQP gem embraces this fact.
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
  # refer to documentation for those methods for usage examples.
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
  #
  # h2. Error handling
  #
  # It is possible (and, indeed, recommended) to handle channel-level exceptions by defining an errback using #on_error:
  #
  # @example Queue declaration with incompatible attributes results in a channel-level exception
  #   AMQP.start("amqp://guest:guest@dev.rabbitmq.com:5672/") do |connection, open_ok|
  #     AMQP::Channel.new do |channel, open_ok|
  #       puts "Channel ##{channel.id} is now open!"
  #
  #       channel.on_error do |ch, close|
  #         puts "Handling channel-level exception"
  #
  #         connection.close {
  #           EM.stop { exit }
  #         }
  #       end
  #
  #       EventMachine.add_timer(0.4) do
  #         # these two definitions result in a race condition. For sake of this example,
  #         # however, it does not matter. Whatever definition succeeds first, 2nd one will
  #         # cause a channel-level exception (because attributes are not identical)
  #         AMQP::Queue.new(channel, "amqpgem.examples.channel_exception", :auto_delete => true, :durable => false) do |queue|
  #           puts "#{queue.name} is ready to go"
  #         end
  #
  #         AMQP::Queue.new(channel, "amqpgem.examples.channel_exception", :auto_delete => true, :durable => true) do |queue|
  #           puts "#{queue.name} is ready to go"
  #         end
  #       end
  #     end
  #   end
  #
  # <script src="https://gist.github.com/939490.js?file=gistfile1.rb"></script>
  #
  # When channel-level exception is indicated by the broker and errback defined using #on_error is run, channel is already
  # closed and all queue and exchange objects associated with this channel are reset. The recommended way to recover from
  # channel-level exceptions is to open a new channel and re-instantiate queues, exchanges and bindings your application
  # needs.
  #
  #
  #
  # h2. Closing a channel
  #
  # Channels are opened when objects is instantiated and closed using {#close} method when application no longer
  # needs it.
  #
  # @example Closing a channel your application no longer needs
  #   # this assumes EventMachine reactor is running
  #   AMQP.connect("amqp://guest:guest@dev.rabbitmq.com:5672") do |client|
  #     AMQP::Channel.new(client) do |channel, open_ok|
  #       channel.close do |close_ok|
  #         # when this block is executed, channel is successfully closed
  #       end
  #     end
  #   end
  #
  # <script src="https://gist.github.com/939483.js?file=gistfile1.rb"></script>
  #
  #
  # h2. RabbitMQ extensions.
  #
  # AMQP gem supports several RabbitMQ extensions taht extend Channel functionality.
  # Learn more in {file:docs/VendorSpecificExtensions.textile}
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


    # @note We encourage you to not rely on default AMQP connection and pass connection parameter
    #       explicitly.
    #
    # @param [AMQP::Session] connection Connection to open this channel on. If not given, default AMQP
    #                                   connection (accessible via {AMQP.connection}) will be used.
    # @param [Integer]       id         Channel id. Must not be greater than max channel id client and broker
    #                                   negotiated on during connection setup. Almost always the right thing to do
    #                                   is to let AMQP gem pick channel identifier for you. If you want to get next
    #                                   channel id, use {AMQP::Channel.next_channel_id} (it is thread-safe).
    # @param [Hash]          options    A hash of options
    #
    # @example Instantiating a channel for default connection (accessible as AMQP.connection)
    #
    #   AMQP.connect do |connection|
    #     AMQP::Channel.new(connection) do |channel, open_ok|
    #       # channel is ready: set up your messaging flow by creating exchanges,
    #       # queues, binding them together and so on.
    #     end
    #   end
    #
    # @example Instantiating a channel for explicitly given connection
    #
    #   AMQP.connect do |connection|
    #     AMQP::Channel.new(connection) do |channel, open_ok|
    #       # ...
    #     end
    #   end
    #
    # @example Instantiating a channel with a :prefetch option
    #
    #   AMQP.connect do |connection|
    #     AMQP::Channel.new(connection, AMQP::Channel.next_channel_id, :prefetch => 5) do |channel, open_ok|
    #       # ...
    #     end
    #   end
    #
    #
    # @option options [Boolean] :prefetch (nil)  Specifies number of messages to prefetch. Channel-specific. See {AMQP::Channel#prefetch}.
    #
    # @yield [channel, open_ok] Yields open channel instance and AMQP method (channel.open-ok) instance. The latter is optional.
    # @yieldparam [Channel] channel Channel that is successfully open
    # @yieldparam [AMQP::Protocol::Channel::OpenOk] open_ok AMQP channel.open-ok) instance
    #
    #
    # @see AMQP::Channel#prefetch
    # @api public
    def initialize(connection = nil, id = self.class.next_channel_id, options = {}, &block)
      raise 'AMQP can only be used from within EM.run {}' unless EM.reactor_running?

      @connection = connection || AMQP.connection || AMQP.start

      super(@connection, id)

      @rpcs                       = Hash.new
      # we need this deferrable to mimic what AMQP gem 0.7 does to enable
      # the following (HIGHLY discouraged) style of programming some people use in their
      # existing codebases:
      #
      # connection = AMQP.connect
      # channel    = AMQP::Channel.new(connection)
      # queue      = AMQP::Queue.new(channel)
      #
      # ...
      #
      # Read more about EM::Deferrable#callback behavior in EventMachine documentation. MK.
      @channel_is_open_deferrable = AMQ::Client::EventMachineClient::Deferrable.new

      # only send channel.open when connection is actually open. Makes it possible to
      # do c = AMQP.connect; AMQP::Channel.new(c) that is what some people do. MK.
      @connection.on_connection do
        self.open do |ch, open_ok|
          @channel_is_open_deferrable.succeed

          if block
            case block.arity
            when 1 then block.call(ch)
            else block.call(ch, open_ok)
            end # case
          end # if

          self.prefetch(options[:prefetch], false) if options[:prefetch]
        end # self.open
      end # @connection.on_open
    end

    # Takes a block that will be deferred till the moment when channel is considered open
    # (channel.open-ok is received from the broker). If you need to delay an operation
    # till the moment channel is open, this method is what you are looking for.
    #
    # Multiple callbacks are supported. If when this moment is called, channel is already
    # open, block is executed immediately.
    #
    # @api public
    def once_open(&block)
      @channel_is_open_deferrable.callback(&block)
    end # once_open(&block)
    alias once_opened once_open


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
    # @example Using default pre-declared direct exchange and no callbacks (pseudo-synchronous style)
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
    # @example Instantiating a direct exchange using {Channel#direct} with a callback
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
    # queues when routing key matches queue name exactly. This feature is known as
    # "automatic binding" (of queues to default exchange).
    #
    # *Use default exchange when you want to route messages directly to specific queues*
    # (queue names are known, you don't mind this kind of coupling between applications).
    #
    #
    # @example Using default exchange to publish messages to queues with known names
    #   AMQP.start(:host => 'localhost') do |connection|
    #     ch        = AMQP::Channel.new(connection)
    #
    #     queue1    = ch.queue("queue1").subscribe do |payload|
    #       puts "[#{queue1.name}] => #{payload}"
    #     end
    #     queue2    = ch.queue("queue2").subscribe do |payload|
    #       puts "[#{queue2.name}] => #{payload}"
    #     end
    #     queue3    = ch.queue("queue3").subscribe do |payload|
    #       puts "[#{queue3.name}] => #{payload}"
    #     end
    #     queues    = [queue1, queue2, queue3]
    #
    #     # Rely on default direct exchange binding, see section 2.1.2.4 Automatic Mode in AMQP 0.9.1 spec.
    #     exchange = AMQP::Exchange.default
    #     EM.add_periodic_timer(1) do
    #       q = queues.sample
    #
    #       exchange.publish "Some payload from #{Time.now.to_i}", :routing_key => q.name
    #     end
    #   end
    #
    #
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
    # @example Using topic exchange to deliver relevant news updates
    #   AMQP.connect do |connection|
    #     channel  = AMQP::Channel.new(connection)
    #     exchange = channel.topic("pub/sub")
    #
    #     # Subscribers.
    #     channel.queue("development").bind(exchange, :key => "technology.dev.#").subscribe do |payload|
    #       puts "A new dev post: '#{payload}'"
    #     end
    #     channel.queue("ruby").bind(exchange, :key => "technology.#.ruby").subscribe do |payload|
    #       puts "A new post about Ruby: '#{payload}'"
    #     end
    #
    #     # Let's publish some data.
    #     exchange.publish "Ruby post",     :routing_key => "technology.dev.ruby"
    #     exchange.publish "Erlang post",   :routing_key => "technology.dev.erlang"
    #     exchange.publish "Sinatra post",  :routing_key => "technology.web.ruby"
    #     exchange.publish "Jewelery post", :routing_key => "jewelery.ruby"
    #   end
    #
    #
    # @example Using topic exchange to deliver geographically-relevant data
    #   AMQP.connect do |connection|
    #     channel  = AMQP::Channel.new(connection)
    #     exchange = channel.topic("pub/sub")
    #
    #     # Subscribers.
    #     channel.queue("americas.north").bind(exchange, :routing_key => "americas.north.#").subscribe do |headers, payload|
    #       puts "An update for North America: #{payload}, routing key is #{headers.routing_key}"
    #     end
    #     channel.queue("americas.south").bind(exchange, :routing_key => "americas.south.#").subscribe do |headers, payload|
    #       puts "An update for South America: #{payload}, routing key is #{headers.routing_key}"
    #     end
    #     channel.queue("us.california").bind(exchange, :routing_key => "americas.north.us.ca.*").subscribe do |headers, payload|
    #       puts "An update for US/California: #{payload}, routing key is #{headers.routing_key}"
    #     end
    #     channel.queue("us.tx.austin").bind(exchange, :routing_key => "#.tx.austin").subscribe do |headers, payload|
    #       puts "An update for Austin, TX: #{payload}, routing key is #{headers.routing_key}"
    #     end
    #     channel.queue("it.rome").bind(exchange, :routing_key => "europe.italy.rome").subscribe do |headers, payload|
    #       puts "An update for Rome, Italy: #{payload}, routing key is #{headers.routing_key}"
    #     end
    #     channel.queue("asia.hk").bind(exchange, :routing_key => "asia.southeast.hk.#").subscribe do |headers, payload|
    #       puts "An update for Hong Kong: #{payload}, routing key is #{headers.routing_key}"
    #     end
    #
    #     exchange.publish("San Diego update", :routing_key => "americas.north.us.ca.sandiego").
    #       publish("Berkeley update",         :routing_key => "americas.north.us.ca.berkeley").
    #       publish("San Francisco update",    :routing_key => "americas.north.us.ca.sanfrancisco").
    #       publish("New York update",         :routing_key => "americas.north.us.ny.newyork").
    #       publish("São Paolo update",        :routing_key => "americas.south.brazil.saopaolo").
    #       publish("Hong Kong update",        :routing_key => "asia.southeast.hk.hongkong").
    #       publish("Kyoto update",            :routing_key => "asia.southeast.japan.kyoto").
    #       publish("Shanghai update",         :routing_key => "asia.southeast.prc.shanghai").
    #       publish("Rome update",             :routing_key => "europe.italy.roma").
    #       publish("Paris update",            :routing_key => "europe.france.paris")
    #   end
    #
    # @see Exchange
    # @see Exchange#initialize
    # @see http://www.rabbitmq.com/faq.html#Binding-and-Routing RabbitMQ FAQ on routing & wildcards
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


    # Declares and returns a Queue instance associated with this channel. See {Queue Queue class documentation} for
    # more information about queues.
    #
    # To make broker generate queue name for you (a classic example is exclusive
    # queues that are only used for a short period of time), pass empty string
    # as name value. Then queue will get it's name as soon as broker's response
    # (queue.declare-ok) arrives. Note that in this case, block is required.
    #
    #
    # Like for exchanges, queue names starting with 'amq.' cannot be modified and
    # should not be used by applications.
    #
    # @example Declaring a queue in a mail delivery app using Channel#queue without a block
    #   AMQP.connect do |connection|
    #     AMQP::Channel.new(connection) do |ch|
    #       # message producers will be able to send messages to this queue
    #       # using direct exchange and routing key = "mail.delivery"
    #       queue = ch.queue("mail.delivery", :durable => true)
    #       queue.subscribe do |headers, payload|
    #         # ...
    #       end
    #     end
    #   end
    #
    # @example Declaring a server-named exclusive queue that receives all messages related to events, using a block.
    #   AMQP.connect do |connection|
    #     AMQP::Channel.new(connection) do |ch|
    #       # message producers will be able to send messages to this queue
    #       # using amq.topic exchange with routing keys that begin with "events"
    #       ch.queue("", :exclusive => true) do |queue|
    #         queue.bind(ch.exchange("amq.topic"), :routing_key => "events.#").subscribe do |headers, payload|
    #           # ...
    #         end
    #       end
    #     end
    #   end
    #
    # @param [String] name Queue name. If you want a server-named queue, you can omit the name (note that in this case, using block is mandatory).
    #                                  See {Queue Queue class documentation} for discussion of queue lifecycles and when use of server-named queues
    #                                  is optimal.
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
    #
    # @yield [queue, declare_ok] Yields successfully declared queue instance and AMQP method (queue.declare-ok) instance. The latter is optional.
    # @yieldparam [Queue] queue Queue that is successfully declared and is ready to be used.
    # @yieldparam [AMQP::Protocol::Queue::DeclareOk] declare_ok AMQP queue.declare-ok) instance.
    #
    # @see Queue
    # @see Queue#initialize
    # @see http://bit.ly/hw2ELX AMQP 0.9.1 specification (Section 2.1.4)
    #
    # @return [Queue]
    # @api public
    def queue(name = AMQ::Protocol::EMPTY_STRING, opts = {}, &block)
      if name && !name.empty? && (queue = find_queue(name))
        extended_opts = Queue.add_default_options(name, opts, block)

        validate_parameters_match!(queue, extended_opts)

        queue
      else
        self.queue!(name, opts, &block)
      end
    end

    # Returns true if channel is not closed.
    # @return [Boolean]
    # @api public
    def open?
      self.status == :opened || self.status == :opening
    end # open?

    # Same as {Channel#queue} but when queue with the same name already exists in this channel
    # object's cache, this method will replace existing queue with a newly defined one. Consider
    # using {Channel#queue} instead.
    #
    # @see Channel#queue
    #
    # @return [Queue]
    # @api public
    def queue!(name, opts = {}, &block)
      queue = if block.nil?
                Queue.new(self, name, opts)
              else
                shim = Proc.new { |q, method|
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
    # used to send messages and arguments to the queue. See {AMQP::RPC#method_missing}
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




    # @param [Fixnum] Message count
    # @param [Boolean] global (false)
    #
    # @return [Channel] self
    #
    # @api public
    def prefetch(count, global = false, &block)
      self.once_open do
        # RabbitMQ as of 2.3.1 does not support prefetch_size.
        self.qos(0, count, global, &block)
      end

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


    # Defines a global callback to be run on channel-level exception across
    # all channels. Consider using Channel#on_error instead. This method is here for sake
    # of backwards compatibility with 0.6.x and 0.7.x releases.
    #
    # @param [String] msg Error message that passed to previously defined handler
    #
    # @deprecated
    # @api public
    # @private
    def self.error(msg = nil, &block)
      if block
        @global_error_handler = block
      else
        @global_error_handler.call(msg) if @global_error_handler && msg
      end
    end

    # Defines a global callback to be run on channel-level exception across
    # all channels. Consider using Channel#on_error instead. This method is here for sake
    # of backwards compatibility with 0.6.x and 0.7.x releases.
    # @see AMQP::Channel#on_error
    # @deprecated
    # @api public
    def self.on_error(&block)
      self.error(&block)
    end # self.on_error(&block)

    # Overrides AMQ::Client::Channel version to also call global callback
    # (if defined) for backwards compatibility.
    #
    # @private
    # @api private
    def handle_close(method)
      super(method)

      self.class.error(method.reply_text)
    end


    # Resets channel state (for example, list of registered queue objects and so on).
    #
    # Most of the time, this method is not
    # called by application code.
    #
    # @private
    # @api plugin
    def reset
      # See AMQ::Client::Channel
      self.reset_state!

      # there is no way to reset a deferrable; we have to use a new instance. MK.
      @channel_is_open_deferrable = AMQ::Client::EventMachineClient::Deferrable.new
    end

    # @private
    # @api plugin
    def reset_state!
      super
      @rpcs = Hash.new
    end # reset_state!


    # Overrides superclass method to also re-create @channel_is_open_deferrable
    #
    # @api plugin
    # @private
    def handle_connection_interruption(exception = nil)
      super(exception)
      @channel_is_open_deferrable = AMQ::Client::EventMachineClient::Deferrable.new
    end


    # @private
    # @api private
    def self.channel_id_mutex
      @channel_id_mutex ||= Mutex.new
    end

    # Returns incrementing channel id. This method is thread safe.
    # @return [Fixnum]
    # @api public
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

    # @private
    def validate_parameters_match!(entity, parameters)
      unless entity.opts == parameters || parameters[:passive]
        raise AMQP::IncompatibleOptionsError.new(entity.name, entity.opts, parameters)
      end
    end # validate_parameters_match!(entity, parameters)
  end # Channel
end # AMQP
