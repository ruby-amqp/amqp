# encoding: utf-8

require "amqp/int_allocator"
require "amqp/exchange"
require "amqp/queue"

module AMQP
  # h2. What are AMQP channels
  #
  # To quote {http://files.travis-ci.org/docs/amqp/0.9.1/AMQP091Specification.pdf AMQP 0.9.1 specification}:
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
  #   AMQP.start("amqp://guest:guest@dev.rabbitmq.com:5672") do |connection, open_ok|
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
  # AMQP gem supports several RabbitMQ extensions that extend Channel functionality.
  # Learn more in {file:docs/VendorSpecificExtensions.textile}
  #
  # @see http://files.travis-ci.org/docs/amqp/0.9.1/AMQP091Specification.pdf AMQP 0.9.1 specification (Section 2.2.5)
  class Channel

    #
    # Behaviours
    #

    extend  RegisterEntityMixin
    include Entity
    extend  ProtocolMethodHandlers

    register_entity :queue,    AMQP::Queue
    register_entity :exchange, AMQP::Exchange


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

    DEFAULT_REPLY_TEXT = "Goodbye".freeze

    attr_reader :id

    attr_reader :exchanges_awaiting_declare_ok, :exchanges_awaiting_delete_ok, :exchanges_awaiting_bind_ok, :exchanges_awaiting_unbind_ok
    attr_reader :queues_awaiting_declare_ok, :queues_awaiting_delete_ok, :queues_awaiting_bind_ok, :queues_awaiting_unbind_ok, :queues_awaiting_purge_ok, :queues_awaiting_get_response
    attr_reader :consumers_awaiting_consume_ok, :consumers_awaiting_cancel_ok

    attr_accessor :flow_is_active

    # Change publisher index. Publisher index is incremented
    # by 1 after each Basic.Publish starting at 1. This is done
    # on both client and server, hence this acknowledged messages
    # can be matched via its delivery-tag.
    #
    # @api private
    attr_writer :publisher_index


    # @param [AMQP::Session] connection Connection to open this channel on. If not given, default AMQP
    #                                   connection (accessible via {AMQP.connection}) will be used.
    # @param [Integer]       id         Channel id. Must not be greater than max channel id client and broker
    #                                   negotiated on during connection setup. Almost always the right thing to do
    #                                   is to let AMQP gem pick channel identifier for you.
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
    #     AMQP::Channel.new(connection, :prefetch => 5) do |channel, open_ok|
    #       # ...
    #     end
    #   end
    #
    #
    # @option options [Boolean] :prefetch (nil)  Specifies number of messages to prefetch. Channel-specific. See {AMQP::Channel#prefetch}.
    # @option options [Boolean] :auto_recovery (nil)  Turns on automatic network failure recovery mode for this channel.
    #
    # @yield [channel, open_ok] Yields open channel instance and AMQP method (channel.open-ok) instance. The latter is optional.
    # @yieldparam [Channel] channel Channel that is successfully open
    # @yieldparam [AMQP::Protocol::Channel::OpenOk] open_ok AMQP channel.open-ok) instance
    #
    #
    # @see AMQP::Channel#prefetch
    # @api public
    def initialize(connection = nil, id = nil, options = {}, &block)
      raise 'AMQP can only be used from within EM.run {}' unless EM.reactor_running?

      @connection = connection || AMQP.connection || AMQP.start
      # this means 2nd argument is options
      if id.kind_of?(Hash)
        options = options.merge(id)
        id      = @connection.next_channel_id
      end

      super(@connection)

      @id        = id || @connection.next_channel_id
      @exchanges = Hash.new
      @queues    = Hash.new
      @consumers = Hash.new
      @options       = { :auto_recovery => @connection.auto_recovering? }.merge(options)
      @auto_recovery = (!!@options[:auto_recovery])

      # we must synchronize frameset delivery. MK.
      @mutex     = Mutex.new

      reset_state!

      # 65536 is here for cases when channel is opened without passing a callback in,
      # otherwise channel_mix would be nil and it causes a lot of needless headaches.
      # lets just have this default. MK.
      channel_max = if @connection.open?
                      @connection.channel_max || 65536
                    else
                      65536
                    end

      if channel_max != 0 && !(0..channel_max).include?(@id)
        raise ArgumentError.new("Max channel for the connection is #{channel_max}, given: #{@id}")
      end

      # we need this deferrable to mimic what AMQP gem 0.7 does to enable
      # the following (pseudo-synchronous) style of programming some people use in their
      # existing codebases:
      #
      # connection = AMQP.connect
      # channel    = AMQP::Channel.new(connection)
      # queue      = AMQP::Queue.new(channel)
      #
      # ...
      #
      # Read more about EM::Deferrable#callback behavior in EventMachine documentation. MK.
      @channel_is_open_deferrable = AMQP::Deferrable.new

      @parameter_checks = {:queue => [:durable, :exclusive, :auto_delete, :arguments], :exchange => [:type, :durable, :arguments]}

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

          self.prefetch(@options[:prefetch], false) if @options[:prefetch]
        end # self.open
      end # @connection.on_open
    end

    # @return [Boolean] true if this channel is in automatic recovery mode
    # @see #auto_recovering?
    attr_accessor :auto_recovery

    # @return [Boolean] true if this channel uses automatic recovery mode
    def auto_recovering?
      @auto_recovery
    end # auto_recovering?

    # Called by associated connection object when AMQP connection has been re-established
    # (for example, after a network failure).
    #
    # @api plugin
    def auto_recover
      return unless auto_recovering?

      @channel_is_open_deferrable.fail
      @channel_is_open_deferrable = AMQP::Deferrable.new

      self.open do
        @channel_is_open_deferrable.succeed

        # re-establish prefetch
        self.prefetch(@options[:prefetch], false) if @options[:prefetch]

        # exchanges must be recovered first because queue recovery includes recovery of bindings. MK.
        @exchanges.each { |name, e| e.auto_recover }
        @queues.each    { |name, q| q.auto_recover }
      end
    end # auto_recover

    # Can be used to recover channels from channel-level exceptions. Allocates a new channel id and reopens
    # itself with this new id, releasing the old id after the new one is allocated.
    #
    # This includes recovery of known exchanges, queues and bindings, exactly the same way as when
    # the client recovers from a network failure.
    #
    # @api public
    def reuse
      old_id = @id
      # must release after we allocate a new id, otherwise we will end up
      # with the same value. MK.
      @id    = self.class.next_channel_id
      @connection.release_channel_id(old_id)

      @channel_is_open_deferrable.fail
      @channel_is_open_deferrable = AMQP::Deferrable.new

      self.open do
        @channel_is_open_deferrable.succeed

        # re-establish prefetch
        self.prefetch(@options[:prefetch], false) if @options[:prefetch]

        # exchanges must be recovered first because queue recovery includes recovery of bindings. MK.
        @exchanges.each { |name, e| e.auto_recover }
        @queues.each    { |name, q| q.auto_recover }
      end
    end # reuse



    # @group Declaring exchanges

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
    # @see http://files.travis-ci.org/docs/amqp/0.9.1/AMQP091Specification.pdf AMQP 0.9.1 specification (Section 3.1.3.1)
    #
    # @return [Exchange]
    # @api public
    def direct(name = 'amq.direct', opts = {}, &block)
      if exchange = find_exchange(name)
        extended_opts = Exchange.add_default_options(:direct, name, opts, block)

        validate_parameters_match!(exchange, extended_opts, :exchange)

        block.call(exchange) if block
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
    # @see http://files.travis-ci.org/docs/amqp/0.9.1/AMQP091Specification.pdf AMQP 0.9.1 specification (Section 2.1.2.4)
    #
    # @return [Exchange]
    # @api public
    def default_exchange
      @default_exchange ||= Exchange.default(self)
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
    # @see http://files.travis-ci.org/docs/amqp/0.9.1/AMQP091Specification.pdf AMQP 0.9.1 specification (Section 3.1.3.2)
    #
    # @return [Exchange]
    # @api public
    def fanout(name = 'amq.fanout', opts = {}, &block)
      if exchange = find_exchange(name)
        extended_opts = Exchange.add_default_options(:fanout, name, opts, block)

        validate_parameters_match!(exchange, extended_opts, :exchange)

        block.call(exchange) if block
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
    # @see http://files.travis-ci.org/docs/amqp/0.9.1/AMQP091Specification.pdf AMQP 0.9.1 specification (Section 3.1.3.3)
    #
    # @return [Exchange]
    # @api public
    def topic(name = 'amq.topic', opts = {}, &block)
      if exchange = find_exchange(name)
        extended_opts = Exchange.add_default_options(:topic, name, opts, block)

        validate_parameters_match!(exchange, extended_opts, :exchange)

        block.call(exchange) if block
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
    # @example Using headers exchange to route messages based on multiple attributes (OS, architecture, # of cores)
    #
    #   puts "=> Headers routing example"
    #   puts
    #   AMQP.start do |connection|
    #     channel   = AMQP::Channel.new(connection)
    #     channel.on_error do |ch, channel_close|
    #       puts "A channel-level exception: #{channel_close.inspect}"
    #     end
    #
    #     exchange = channel.headers("amq.match", :durable => true)
    #
    #     channel.queue("", :auto_delete => true).bind(exchange, :arguments => { 'x-match' => 'all', :arch => "x64", :os => 'linux' }).subscribe do |metadata, payload|
    #       puts "[linux/x64] Got a message: #{payload}"
    #     end
    #     channel.queue("", :auto_delete => true).bind(exchange, :arguments => { 'x-match' => 'all', :arch => "x32", :os => 'linux' }).subscribe do |metadata, payload|
    #       puts "[linux/x32] Got a message: #{payload}"
    #     end
    #     channel.queue("", :auto_delete => true).bind(exchange, :arguments => { 'x-match' => 'any', :os => 'linux', :arch => "__any__" }).subscribe do |metadata, payload|
    #       puts "[linux] Got a message: #{payload}"
    #     end
    #     channel.queue("", :auto_delete => true).bind(exchange, :arguments => { 'x-match' => 'any', :os => 'macosx', :cores => 8 }).subscribe do |metadata, payload|
    #       puts "[macosx|octocore] Got a message: #{payload}"
    #     end
    #
    #
    #     EventMachine.add_timer(0.5) do
    #       exchange.publish "For linux/x64",   :headers => { :arch => "x64", :os => 'linux' }
    #       exchange.publish "For linux/x32",   :headers => { :arch => "x32", :os => 'linux' }
    #       exchange.publish "For linux",       :headers => { :os => 'linux'  }
    #       exchange.publish "For OS X",        :headers => { :os => 'macosx' }
    #       exchange.publish "For solaris/x64", :headers => { :os => 'solaris', :arch => 'x64' }
    #       exchange.publish "For ocotocore",   :headers => { :cores => 8  }
    #     end
    #
    #
    #     show_stopper = Proc.new do
    #       $stdout.puts "Stopping..."
    #       connection.close {
    #         EventMachine.stop { exit }
    #       }
    #     end
    #
    #     Signal.trap "INT", show_stopper
    #     EventMachine.add_timer(2, show_stopper)
    #   end
    #
    #
    #
    # @see Exchange
    # @see Exchange#initialize
    # @see Channel#default_exchange
    # @see http://files.travis-ci.org/docs/amqp/0.9.1/AMQP091Specification.pdf AMQP 0.9.1 specification (Section 3.1.3.3)
    #
    # @return [Exchange]
    # @api public
    def headers(name = 'amq.match', opts = {}, &block)
      if exchange = find_exchange(name)
        extended_opts = Exchange.add_default_options(:headers, name, opts, block)

        validate_parameters_match!(exchange, extended_opts, :exchange)

        block.call(exchange) if block
        exchange
      else
        register_exchange(Exchange.new(self, :headers, name, opts, &block))
      end
    end

    # @endgroup


    # @group Declaring queues


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
    # @yield [queue, declare_ok] Yields successfully declared queue instance and AMQP method (queue.declare-ok) instance. The latter is optional.
    # @yieldparam [Queue] queue Queue that is successfully declared and is ready to be used.
    # @yieldparam [AMQP::Protocol::Queue::DeclareOk] declare_ok AMQP queue.declare-ok) instance.
    #
    # @see Queue
    # @see Queue#initialize
    # @see http://files.travis-ci.org/docs/amqp/0.9.1/AMQP091Specification.pdf AMQP 0.9.1 specification (Section 2.1.4)
    #
    # @return [Queue]
    # @api public
    def queue(name = AMQ::Protocol::EMPTY_STRING, opts = {}, &block)
      raise ArgumentError.new("queue name must not be nil; if you want broker to generate queue name for you, pass an empty string") if name.nil?

      if name && !name.empty? && (queue = find_queue(name))
        extended_opts = Queue.add_default_options(name, opts, block)

        validate_parameters_match!(queue, extended_opts, :queue)

        block.call(queue) if block
        queue
      else
        self.queue!(name, opts, &block)
      end
    end

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
          if block.arity == 1
            block.call(q)
          else
            queue = find_queue(method.queue)
            block.call(queue, method.consumer_count, method.message_count)
          end
        }
                Queue.new(self, name, opts, &shim)
              end

      register_queue(queue)
    end

    # @return [Array<AMQP::Queue>] Queues cache for this channel
    # @api plugin
    # @private
    def queues
      @queues
    end # queues

    # @endgroup




    # @group Channel lifecycle

    # Opens AMQP channel.
    #
    # @note Instantiated channels are opened by default. This method should only be used for error recovery after network connection loss.
    # @api public
    def open(&block)
      @connection.send_frame(AMQ::Protocol::Channel::Open.encode(@id, AMQ::Protocol::EMPTY_STRING))
      @connection.channels[@id] = self
      self.status = :opening

      self.redefine_callback :open, &block
    end
    alias reopen open


    # @return [Boolean] true if channel is not closed.
    # @api public
    def open?
      self.status == :opened || self.status == :opening
    end # open?

    # Takes a block that will be deferred till the moment when channel is considered open
    # (channel.open-ok is received from the broker). If you need to delay an operation
    # till the moment channel is open, this method is what you are looking for.
    #
    # Multiple callbacks are supported. If when this moment is called, channel is already
    # open, block is executed immediately.
    #
    # @api public
    def once_open(&block)
      @channel_is_open_deferrable.callback do
        # guards against cases when deferred operations
        # don't complete before the channel is closed
        block.call if open?
      end
    end # once_open(&block)
    alias once_opened once_open

    # @return [Boolean]
    # @api public
    def closing?
      self.status == :closing
    end

    # Closes AMQP channel.
    #
    # @api public
    def close(reply_code = 200, reply_text = DEFAULT_REPLY_TEXT, class_id = 0, method_id = 0, &block)
      self.once_open do
        self.status = :closing
        @connection.send_frame(AMQ::Protocol::Channel::Close.encode(@id, reply_code, reply_text, class_id, method_id))

        self.redefine_callback :close, &block
      end
    end

    # @endgroup




    # @group QoS and flow handling

    # Asks the peer to pause or restart the flow of content data sent to a consumer.
    # This is a simple flow­control mechanism that a peer can use to avoid overflowing its
    # queues or otherwise finding itself receiving more messages than it can process. Note that
    # this method is not intended for window control. It does not affect contents returned to
    # Queue#get callers.
    #
    # @param [Boolean] Desired flow state.
    #
    # @see http://files.travis-ci.org/docs/amqp/0.9.1/AMQP091Reference.pdf AMQP 0.9.1 protocol documentation (Section 1.5.2.3.)
    # @api public
    def flow(active = false, &block)
      @connection.send_frame(AMQ::Protocol::Channel::Flow.encode(@id, active))

      self.redefine_callback :flow, &block
      self
    end

    # @return [Boolean]  True if flow in this channel is active (messages will be delivered to consumers that use this channel).
    #
    # @api public
    def flow_is_active?
      @flow_is_active
    end # flow_is_active?



    # @param [Fixnum] Message count
    # @param [Boolean] global (false)
    #
    # @return [Channel] self
    #
    # @api public
    def prefetch(count, global = false, &block)
      self.once_open do
        # RabbitMQ does not support prefetch_size.
        self.qos(0, count, global, &block)

        @options[:prefetch] = count
      end

      self
    end

    # @endgroup



    # @group Message acknowledgements

    # Acknowledge one or all messages on the channel.
    #
    # @api public
    # @see #reject
    # @see #recover
    # @see http://files.travis-ci.org/docs/amqp/0.9.1/AMQP091Reference.pdf AMQP 0.9.1 protocol documentation (Section 1.8.3.13.)
    def acknowledge(delivery_tag, multiple = false)
      @connection.send_frame(AMQ::Protocol::Basic::Ack.encode(self.id, delivery_tag, multiple))

      self
    end # acknowledge(delivery_tag, multiple = false)

    # Reject a message with given delivery tag.
    #
    # @api public
    # @see #acknowledge
    # @see #recover
    # @see http://files.travis-ci.org/docs/amqp/0.9.1/AMQP091Reference.pdf AMQP 0.9.1 protocol documentation (Section 1.8.3.14.)
    def reject(delivery_tag, requeue = true, multi = false)
      if multi
        @connection.send_frame(AMQ::Protocol::Basic::Nack.encode(self.id, delivery_tag, multi, requeue))
      else
        @connection.send_frame(AMQ::Protocol::Basic::Reject.encode(self.id, delivery_tag, requeue))
      end

      self
    end # reject(delivery_tag, requeue = true)

    # Notifies AMQ broker that consumer has recovered and unacknowledged messages need
    # to be redelivered.
    #
    # @return [Channel]  self
    #
    # @note RabbitMQ as of 2.3.1 does not support basic.recover with requeue = false.
    # @see http://files.travis-ci.org/docs/amqp/0.9.1/AMQP091Reference.pdf AMQP 0.9.1 protocol documentation (Section 1.8.3.16.)
    # @see #acknowledge
    # @api public
    def recover(requeue = true, &block)
      @connection.send_frame(AMQ::Protocol::Basic::Recover.encode(@id, requeue))

      self.redefine_callback :recover, &block
      self
    end # recover(requeue = false, &block)

    # @endgroup




    # @group Transactions

    # Sets the channel to use standard transactions. One must use this method at least
    # once on a channel before using #tx_tommit or tx_rollback methods.
    #
    # @api public
    def tx_select(&block)
      @connection.send_frame(AMQ::Protocol::Tx::Select.encode(@id))

      self.redefine_callback :tx_select, &block
      self
    end # tx_select(&block)

    # Commits AMQP transaction.
    #
    # @api public
    def tx_commit(&block)
      @connection.send_frame(AMQ::Protocol::Tx::Commit.encode(@id))

      self.redefine_callback :tx_commit, &block
      self
    end # tx_commit(&block)

    # Rolls AMQP transaction back.
    #
    # @api public
    def tx_rollback(&block)
      @connection.send_frame(AMQ::Protocol::Tx::Rollback.encode(@id))

      self.redefine_callback :tx_rollback, &block
      self
    end # tx_rollback(&block)


    # @endgroup





    # @group Error handling

    # Defines a callback that will be executed when channel is closed after
    # channel-level exception.
    #
    # @api public
    def on_error(&block)
      self.define_callback(:error, &block)
    end

    # @endgroup


    # @group Publisher Confirms

    def confirm_select(nowait = false, &block)
      self.once_open do
              if nowait && block
        raise ArgumentError, "confirm.select with nowait = true and a callback makes no sense"
      end

      @uses_publisher_confirmations = true
      reset_publisher_index!

      self.redefine_callback(:confirm_select, &block) unless nowait
      self.redefine_callback(:after_publish) do
        increment_publisher_index!
      end
      @connection.send_frame(AMQ::Protocol::Confirm::Select.encode(@id, nowait))

      self
      end
    end

    # @endgroup


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
    def reset(&block)
      # See AMQP::Channel
      self.reset_state!

      # there is no way to reset a deferrable; we have to use a new instance. MK.
      @channel_is_open_deferrable = AMQP::Deferrable.new
      @channel_is_open_deferrable.callback(&block)

      @connection.on_connection do
        @channel_is_open_deferrable.succeed

        self.prefetch(@options[:prefetch], false) if @options[:prefetch]
      end
    end

    # Overrides superclass method to also re-create @channel_is_open_deferrable
    #
    # @api plugin
    # @private
    def handle_connection_interruption(method = nil)
      @queues.each    { |name, q| q.handle_connection_interruption(method) }
      @exchanges.each { |name, e| e.handle_connection_interruption(method) }

      self.exec_callback_yielding_self(:after_connection_interruption)
      self.reset_state!

      @connection.release_channel_id(@id) unless auto_recovering?
      @channel_is_open_deferrable = AMQP::Deferrable.new
    end

    # @return [Hash<String, Consumer>]
    def consumers
      @consumers
    end # consumers

    # @return  [Array<Queue>]   Collection of queues that were declared on this channel.
    def queues
      @queues.values
    end

    # @return  [Array<Exchange>]  Collection of exchanges that were declared on this channel.
    def exchanges
      @exchanges.values
    end


    # AMQP connection this channel belongs to.
    #
    # @return [AMQP::Connection] Connection this channel belongs to.
    def connection
      @connection
    end # connection

    # Synchronizes given block using this channel's mutex.
    # @api public
    def synchronize(&block)
      @mutex.synchronize(&block)
    end

    # @group QoS and flow handling

    # Requests a specific quality of service. The QoS can be specified for the current channel
    # or for all channels on the connection.
    #
    # @note RabbitMQ as of 2.3.1 does not support prefetch_size.
    # @api public
    def qos(prefetch_size = 0, prefetch_count = 32, global = false, &block)
      @connection.send_frame(AMQ::Protocol::Basic::Qos.encode(@id, prefetch_size, prefetch_count, global))

      self.redefine_callback :qos, &block
      self
    end # qos

    # @endgroup



    # @group Error handling


    # Defines a callback that will be executed after TCP connection is interrupted (typically because of a network failure).
    # Only one callback can be defined (the one defined last replaces previously added ones).
    #
    # @api public
    def on_connection_interruption(&block)
      self.redefine_callback(:after_connection_interruption, &block)
    end # on_connection_interruption(&block)
    alias after_connection_interruption on_connection_interruption


    # Defines a callback that will be executed after TCP connection has recovered after a network failure
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

      @queues.each    { |name, q| q.run_before_recovery_callbacks }
      @exchanges.each { |name, e| e.run_before_recovery_callbacks }
    end



    # Defines a callback that will be executed after AMQP connection has recovered after a network failure.
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

      @queues.each    { |name, q| q.run_after_recovery_callbacks }
      @exchanges.each { |name, e| e.run_after_recovery_callbacks }
    end

    # @endgroup


    # Publisher index is an index of the last message since
    # the confirmations were activated, started with 0. It's
    # incremented by 1 every time a message is published.
    # This is done on both client and server, hence this
    # acknowledged messages can be matched via its delivery-tag.
    #
    # @return [Integer] Current publisher index.
    # @api public
    def publisher_index
      @publisher_index ||= 0
    end

    # Resets publisher index to 0
    #
    # @api plugin
    def reset_publisher_index!
      @publisher_index = 0
    end


    # This method is executed after publishing of each message via {Exchage#publish}.
    # Currently it just increments publisher index by 1, so messages
    # can be actually matched.
    #
    # @api plugin
    def increment_publisher_index!
      @publisher_index += 1
    end

    # @return [Boolean]
    def uses_publisher_confirmations?
      @uses_publisher_confirmations
    end # uses_publisher_confirmations?


    # Turn on confirmations for this channel and, if given,
    # register callback for basic.ack from the broker.
    #
    # @raise [RuntimeError] Occurs when confirmations are already activated.
    # @raise [RuntimeError] Occurs when nowait is true and block is given.
    # @param [Boolean] nowait Whether we expect Confirm.Select-Ok to be returned by the broker or not.
    #
    # @yield [basick_ack] Callback which will be executed every time we receive Basic.Ack from the broker.
    # @yieldparam [AMQ::Protocol::Basic::Ack] basick_ack Protocol method class instance.
    #
    # @return [self] self.
    def on_ack(nowait = false, &block)
      self.define_callback(:ack, &block) if block

      self
    end


    # Register error callback for Basic.Nack. It's called
    # when message(s) is rejected.
    #
    # @return [self] self
    def on_nack(&block)
      self.define_callback(:nack, &block) if block

      self
    end




    # Handler for Confirm.Select-Ok. By default, it just
    # executes hook specified via the #confirmations method
    # with a single argument, a protocol method class
    # instance (an instance of AMQ::Protocol::Confirm::SelectOk)
    # and then it deletes the callback, since Confirm.Select
    # is supposed to be sent just once.
    #
    # @api plugin
    def handle_select_ok(method)
      self.exec_callback_once(:confirm_select, method)
    end

    # Handler for Basic.Ack. By default, it just
    # executes hook specified via the #confirm method
    # with a single argument, a protocol method class
    # instance (an instance of AMQ::Protocol::Basic::Ack).
    #
    # @api plugin
    def handle_basic_ack(method)
      self.exec_callback(:ack, method)
    end


    # Handler for Basic.Nack. By default, it just
    # executes hook specified via the #confirm_failed method
    # with a single argument, a protocol method class
    # instance (an instance of AMQ::Protocol::Basic::Nack).
    #
    # @api plugin
    def handle_basic_nack(method)
      self.exec_callback(:nack, method)
    end



    #
    # Implementation
    #

    def register_exchange(exchange)
      raise ArgumentError, "argument is nil!" if exchange.nil?

      @exchanges[exchange.name] = exchange
    end # register_exchange(exchange)

    # Finds exchange in the exchanges cache on this channel by name. Exchange only exists in the cache if
    # it was previously instantiated on this channel.
    #
    # @param [String] name Exchange name
    # @return [AMQP::Exchange] Exchange (if found)
    # @api plugin
    def find_exchange(name)
      @exchanges[name]
    end

    # @api plugin
    # @private
    def register_queue(queue)
      raise ArgumentError, "argument is nil!" if queue.nil?

      @queues[queue.name] = queue
    end # register_queue(queue)

    # @api plugin
    # @private
    def find_queue(name)
      @queues[name]
    end


    RECOVERY_EVENTS = [:after_connection_interruption, :before_recovery, :after_recovery].freeze


    # @api plugin
    # @private
    def reset_state!
      @flow_is_active                = true

      @queues_awaiting_declare_ok    = Array.new
      @exchanges_awaiting_declare_ok = Array.new
      @exchanges_awaiting_bind_ok    = Array.new
      @exchanges_awaiting_unbind_ok  = Array.new

      @queues_awaiting_delete_ok     = Array.new

      @exchanges_awaiting_delete_ok  = Array.new
      @queues_awaiting_purge_ok      = Array.new
      @queues_awaiting_bind_ok       = Array.new
      @queues_awaiting_unbind_ok     = Array.new
      @consumers_awaiting_consume_ok = Array.new
      @consumers_awaiting_cancel_ok  = Array.new

      @queues_awaiting_get_response  = Array.new

      @callbacks                     = @callbacks.delete_if { |k, v| !RECOVERY_EVENTS.include?(k) }
      @uses_publisher_confirmations  = false
    end # reset_state!


    # @api plugin
    # @private
    def handle_open_ok(open_ok)
      self.status = :opened
      self.exec_callback_once_yielding_self(:open, open_ok)
    end

    # @api plugin
    # @private
    def handle_close_ok(close_ok)
      self.status = :closed
      self.connection.clear_frames_on(self.id)
      self.exec_callback_once_yielding_self(:close, close_ok)

      @connection.release_channel_id(@id)
    end

    # @api plugin
    # @private
    def handle_close(channel_close)
      self.status = :closed
      self.connection.clear_frames_on(self.id)

      self.exec_callback_yielding_self(:error, channel_close)
    end



    self.handle(AMQ::Protocol::Channel::OpenOk) do |connection, frame|
      channel = connection.channels[frame.channel]
      channel.handle_open_ok(frame.decode_payload)
    end

    self.handle(AMQ::Protocol::Channel::CloseOk) do |connection, frame|
      method   = frame.decode_payload
      channels = connection.channels

      channel  = channels[frame.channel]
      channels.delete(channel)
      channel.handle_close_ok(method)
    end

    self.handle(AMQ::Protocol::Channel::Close) do |connection, frame|
      method   = frame.decode_payload
      channels = connection.channels
      channel  = channels[frame.channel]
      connection.send_frame(AMQ::Protocol::Channel::CloseOk.encode(frame.channel))
      channel.handle_close(method)
    end

    self.handle(AMQ::Protocol::Basic::QosOk) do |connection, frame|
      channel = connection.channels[frame.channel]
      channel.exec_callback(:qos, frame.decode_payload)
    end

    self.handle(AMQ::Protocol::Basic::RecoverOk) do |connection, frame|
      channel = connection.channels[frame.channel]
      channel.exec_callback(:recover, frame.decode_payload)
    end

    self.handle(AMQ::Protocol::Channel::FlowOk) do |connection, frame|
      channel  = connection.channels[frame.channel]
      method   = frame.decode_payload

      channel.flow_is_active = method.active
      channel.exec_callback(:flow, method)
    end

    self.handle(AMQ::Protocol::Tx::SelectOk) do |connection, frame|
      channel = connection.channels[frame.channel]
      channel.exec_callback(:tx_select, frame.decode_payload)
    end

    self.handle(AMQ::Protocol::Tx::CommitOk) do |connection, frame|
      channel = connection.channels[frame.channel]
      channel.exec_callback(:tx_commit, frame.decode_payload)
    end

    self.handle(AMQ::Protocol::Tx::RollbackOk) do |connection, frame|
      channel = connection.channels[frame.channel]
      channel.exec_callback(:tx_rollback, frame.decode_payload)
    end

    self.handle(AMQ::Protocol::Confirm::SelectOk) do |connection, frame|
      method  = frame.decode_payload
      channel = connection.channels[frame.channel]
      channel.handle_select_ok(method)
    end

    self.handle(AMQ::Protocol::Basic::Ack) do |connection, frame|
      method  = frame.decode_payload
      channel = connection.channels[frame.channel]
      channel.handle_basic_ack(method)
    end

    self.handle(AMQ::Protocol::Basic::Nack) do |connection, frame|
      method  = frame.decode_payload
      channel = connection.channels[frame.channel]
      channel.handle_basic_nack(method)
    end

    protected

    @private
    def validate_parameters_match!(entity, parameters, type)
      unless entity.opts.values_at(*@parameter_checks[type]) == parameters.values_at(*@parameter_checks[type]) || parameters[:passive]
        raise AMQP::IncompatibleOptionsError.new(entity.name, entity.opts, parameters)
      end
    end # validate_parameters_match!(entity, parameters, type)
  end # Channel
end # AMQP
