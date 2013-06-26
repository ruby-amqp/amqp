# encoding: utf-8

require "amq/client/async/entity"
require "amq/client/adapter"
require "amq/client/server_named_entity"

require "amq/protocol/get_response"
require "amq/client/async/consumer"

module AMQ
  module Client
    module Async
      class Queue

        #
        # Behaviours
        #

        include Entity
        include ServerNamedEntity
        extend ProtocolMethodHandlers


        #
        # API
        #

        # Qeueue name. May be server-generated or assigned directly.
        # @return [String]
        attr_reader :name

        # Channel this queue belongs to.
        # @return [AMQ::Client::Channel]
        attr_reader :channel

        # @return [Array<Hash>] All consumers on this queue.
        attr_reader :consumers

        # @return [AMQ::Client::Consumer] Default consumer (registered with {Queue#consume}).
        attr_reader :default_consumer

        # @return [Hash] Additional arguments given on queue declaration. Typically used by AMQP extensions.
        attr_reader :arguments

        # @return [Array<Hash>]
        attr_reader :bindings



        # @param  [AMQ::Client::Adapter]  AMQ networking adapter to use.
        # @param  [AMQ::Client::Channel]  AMQ channel this queue object uses.
        # @param  [String]                Queue name. Please note that AMQP spec does not require brokers to support Unicode for queue names.
        # @api public
        def initialize(connection, channel, name = AMQ::Protocol::EMPTY_STRING)
          raise ArgumentError.new("queue name must not be nil; if you want broker to generate queue name for you, pass an empty string") if name.nil?

          super(connection)

          @name         = name
          # this has to stay true even after queue.declare-ok arrives. MK.
          @server_named = @name.empty?
          if @server_named
            self.on_connection_interruption do
              # server-named queue need to get new names after recovery. MK.
              @name = AMQ::Protocol::EMPTY_STRING
            end
          end

          @channel      = channel

          # primarily for autorecovery. MK.
          @bindings  = Array.new

          @consumers = Hash.new
        end


        # @return [Boolean] true if this queue was declared as durable (will survive broker restart).
        # @api public
        def durable?
          @durable
        end # durable?

        # @return [Boolean] true if this queue was declared as exclusive (limited to just one consumer)
        # @api public
        def exclusive?
          @exclusive
        end # exclusive?

        # @return [Boolean] true if this queue was declared as automatically deleted (deleted as soon as last consumer unbinds).
        # @api public
        def auto_delete?
          @auto_delete
        end # auto_delete?


        # @group Declaration

        # Declares this queue.
        #
        #
        # @return [Queue]  self
        #
        # @api public
        # @see http://bit.ly/amqp091reference AMQP 0.9.1 protocol reference (Section 1.7.2.1.)
        def declare(passive = false, durable = false, exclusive = false, auto_delete = false, nowait = false, arguments = nil, &block)
          raise ArgumentError, "declaration with nowait does not make sense for server-named queues! Either specify name other than empty string or use #declare without nowait" if nowait && self.anonymous?

          # these two are for autorecovery. MK.
          @passive      = passive
          @server_named = @name.empty?

          @durable     = durable
          @exclusive   = exclusive
          @auto_delete = auto_delete
          @arguments   = arguments

          nowait = true if !block && !@name.empty? && nowait.nil?
          @connection.send_frame(Protocol::Queue::Declare.encode(@channel.id, @name, passive, durable, exclusive, auto_delete, nowait, arguments))

          if !nowait
            self.append_callback(:declare, &block)
            @channel.queues_awaiting_declare_ok.push(self)
          end

          self
        end

        # Re-declares queue with the same attributes
        # @api public
        def redeclare(&block)
          nowait = true if !block && !@name.empty?

          # server-named queues get their new generated names.
          new_name = if @server_named
                       AMQ::Protocol::EMPTY_STRING
                     else
                       @name
                     end
          @connection.send_frame(Protocol::Queue::Declare.encode(@channel.id, new_name, @passive, @durable, @exclusive, @auto_delete, false, @arguments))

          if !nowait
            self.append_callback(:declare, &block)
            @channel.queues_awaiting_declare_ok.push(self)
          end

          self
        end

        # @endgroup



        # Deletes this queue.
        #
        # @param [Boolean] if_unused  delete only if queue has no consumers (subscribers).
        # @param [Boolean] if_empty   delete only if queue has no messages in it.
        # @param [Boolean] nowait     Don't wait for reply from broker.
        # @return [Queue]  self
        #
        # @api public
        # @see http://bit.ly/amqp091reference AMQP 0.9.1 protocol reference (Section 1.7.2.9.)
        def delete(if_unused = false, if_empty = false, nowait = false, &block)
          nowait = true unless block
          @connection.send_frame(Protocol::Queue::Delete.encode(@channel.id, @name, if_unused, if_empty, nowait))

          if !nowait
            self.append_callback(:delete, &block)

            # TODO: delete itself from queues cache
            @channel.queues_awaiting_delete_ok.push(self)
          end

          self
        end # delete(channel, queue, if_unused, if_empty, nowait, &block)



        # @group Binding

        #
        # @return [Queue]  self
        #
        # @api public
        # @see http://bit.ly/amqp091reference AMQP 0.9.1 protocol reference (Section 1.7.2.3.)
        def bind(exchange, routing_key = AMQ::Protocol::EMPTY_STRING, nowait = false, arguments = nil, &block)
          nowait = true unless block
          exchange_name = if exchange.respond_to?(:name)
                            exchange.name
                          else

                            exchange
                          end

          @connection.send_frame(Protocol::Queue::Bind.encode(@channel.id, @name, exchange_name, routing_key, nowait, arguments))

          if !nowait
            self.append_callback(:bind, &block)
            @channel.queues_awaiting_bind_ok.push(self)
          end

          # store bindings for automatic recovery, but BE VERY CAREFUL to
          # not cause an infinite rebinding loop here when we recover. MK.
          binding = { :exchange => exchange_name, :routing_key => routing_key, :arguments => arguments }
          @bindings.push(binding) unless @bindings.include?(binding)

          self
        end

        #
        # @return [Queue]  self
        #
        # @api public
        # @see http://bit.ly/amqp091reference AMQP 0.9.1 protocol reference (Section 1.7.2.5.)
        def unbind(exchange, routing_key = AMQ::Protocol::EMPTY_STRING, arguments = nil, &block)
          exchange_name = if exchange.respond_to?(:name)
                            exchange.name
                          else

                            exchange
                          end

          @connection.send_frame(Protocol::Queue::Unbind.encode(@channel.id, @name, exchange_name, routing_key, arguments))

          self.append_callback(:unbind, &block)
          @channel.queues_awaiting_unbind_ok.push(self)


          @bindings.delete_if { |b| b[:exchange] == exchange_name }

          self
        end

        # Used by automatic recovery machinery.
        # @private
        # @api plugin
        def rebind(&block)
          @bindings.each { |b| self.bind(b[:exchange], b[:routing_key], true, b[:arguments]) }
        end

        # @endgroup




        # @group Consuming messages

        # @return [Class] AMQ::Client::Consumer or other class implementing consumer API. Used by libraries like {https://github.com/ruby-amqp/amqp Ruby amqp gem}.
        # @api plugin
        def self.consumer_class
          AMQ::Client::Async::Consumer
        end # self.consumer_class


        #
        # @return [Queue]  self
        #
        # @api public
        # @see http://bit.ly/amqp091reference AMQP 0.9.1 protocol reference (Section 1.8.3.3.)
        def consume(no_ack = false, exclusive = false, nowait = false, no_local = false, arguments = nil, &block)
          raise RuntimeError.new("This queue already has default consumer. Please instantiate AMQ::Client::Consumer directly to register additional consumers.") if @default_consumer

          nowait            = true unless block
          @default_consumer = self.class.consumer_class.new(@channel, self, generate_consumer_tag(@name), exclusive, no_ack, arguments, no_local, &block)
          @default_consumer.consume(nowait, &block)

          self
        end

        # Unsubscribes from message delivery.
        # @return [Queue]  self
        #
        # @api public
        # @see http://bit.ly/amqp091reference AMQP 0.9.1 protocol reference (Section 1.8.3.5.)
        def cancel(nowait = false, &block)
          raise "There is no default consumer for this queue. This usually means that you are trying to unsubscribe a queue that never was subscribed for messages in the first place." if @default_consumer.nil?

          @default_consumer.cancel(nowait, &block)

          self
        end # cancel(&block)

        # @api public
        def on_cancel(&block)
          @default_consumer.on_cancel(&block)
        end # on_cancel(&block)

        # @endgroup




        # @group Working With Messages


        # @api public
        # @see http://bit.ly/amqp091reference AMQP 0.9.1 protocol reference (Sections 1.8.3.9)
        def on_delivery(&block)
          @default_consumer.on_delivery(&block)
        end # on_delivery(&block)


        # Fetches messages from the queue.
        # @return [Queue]  self
        #
        # @api public
        # @see http://bit.ly/amqp091reference AMQP 0.9.1 protocol reference (Section 1.8.3.10.)
        def get(no_ack = false, &block)
          @connection.send_frame(Protocol::Basic::Get.encode(@channel.id, @name, no_ack))

          # most people only want one callback per #get call. Consider the following example:
          #
          # 100.times { queue.get { ... } }
          #
          # most likely you won't expect 100 callback runs per message here. MK.
          self.redefine_callback(:get, &block)
          @channel.queues_awaiting_get_response.push(self)

          self
        end # get(no_ack = false, &block)



        # Purges (removes all messagse from) the queue.
        # @return [Queue]  self
        #
        # @api public
        # @see http://bit.ly/amqp091reference AMQP 0.9.1 protocol reference (Section 1.7.2.7.)
        def purge(nowait = false, &block)
          nowait = true unless block
          @connection.send_frame(Protocol::Queue::Purge.encode(@channel.id, @name, nowait))

          if !nowait
            self.redefine_callback(:purge, &block)
            # TODO: handle channel & connection-level exceptions
            @channel.queues_awaiting_purge_ok.push(self)
          end

          self
        end # purge(nowait = false, &block)

        # @endgroup



        # @group Acknowledging & Rejecting Messages

        # Acknowledge a delivery tag.
        # @return [Queue]  self
        #
        # @api public
        # @see http://bit.ly/amqp091reference AMQP 0.9.1 protocol reference (Section 1.8.3.13.)
        def acknowledge(delivery_tag)
          @channel.acknowledge(delivery_tag)

          self
        end # acknowledge(delivery_tag)

        #
        # @return [Queue]  self
        #
        # @api public
        # @see http://bit.ly/amqp091reference AMQP 0.9.1 protocol reference (Section 1.8.3.14.)
        def reject(delivery_tag, requeue = true)
          @channel.reject(delivery_tag, requeue)

          self
        end # reject(delivery_tag, requeue = true)

        # @endgroup




        # @group Error Handling & Recovery

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
          @consumers.each { |tag, consumer| consumer.handle_connection_interruption(method) }

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

          @consumers.each { |tag, c| c.run_before_recovery_callbacks }
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

          @consumers.each { |tag, c| c.run_after_recovery_callbacks }
        end



        # Called by associated connection object when AMQP connection has been re-established
        # (for example, after a network failure).
        #
        # @api plugin
        def auto_recover
          self.exec_callback_yielding_self(:before_recovery)
          self.redeclare do
            self.rebind

            @consumers.each { |tag, consumer| consumer.auto_recover }

            self.exec_callback_yielding_self(:after_recovery)
          end
        end # auto_recover

        # @endgroup


        #
        # Implementation
        #


        # Unique string supposed to be used as a consumer tag.
        #
        # @return [String]  Unique string.
        # @api plugin
        def generate_consumer_tag(name)
          "#{name}-#{Time.now.to_i * 1000}-#{Kernel.rand(999_999_999_999)}"
        end


        def handle_connection_interruption(method = nil)
          @consumers.each { |tag, c| c.handle_connection_interruption(method) }
        end # handle_connection_interruption(method = nil)


        def handle_declare_ok(method)
          @name = method.queue if @name.empty?
          @channel.register_queue(self)

          self.exec_callback_once_yielding_self(:declare, method)
        end

        def handle_delete_ok(method)
          self.exec_callback_once(:delete, method)
        end # handle_delete_ok(method)

        def handle_purge_ok(method)
          self.exec_callback_once(:purge, method)
        end # handle_purge_ok(method)

        def handle_bind_ok(method)
          self.exec_callback_once(:bind, method)
        end # handle_bind_ok(method)

        def handle_unbind_ok(method)
          self.exec_callback_once(:unbind, method)
        end # handle_unbind_ok(method)

        def handle_get_ok(method, header, payload)
          method = Protocol::GetResponse.new(method)
          self.exec_callback(:get, method, header, payload)
        end # handle_get_ok(method, header, payload)

        def handle_get_empty(method)
          method = Protocol::GetResponse.new(method)
          self.exec_callback(:get, method)
        end # handle_get_empty(method)



        # Get the first queue which didn't receive Queue.Declare-Ok yet and run its declare callback.
        # The cache includes only queues with {nowait: false}.
        self.handle(Protocol::Queue::DeclareOk) do |connection, frame|
          method  = frame.decode_payload

          channel = connection.channels[frame.channel]
          queue   = channel.queues_awaiting_declare_ok.shift

          queue.handle_declare_ok(method)
        end


        self.handle(Protocol::Queue::DeleteOk) do |connection, frame|
          channel = connection.channels[frame.channel]
          queue   = channel.queues_awaiting_delete_ok.shift
          queue.handle_delete_ok(frame.decode_payload)
        end


        self.handle(Protocol::Queue::BindOk) do |connection, frame|
          channel = connection.channels[frame.channel]
          queue   = channel.queues_awaiting_bind_ok.shift

          queue.handle_bind_ok(frame.decode_payload)
        end


        self.handle(Protocol::Queue::UnbindOk) do |connection, frame|
          channel = connection.channels[frame.channel]
          queue   = channel.queues_awaiting_unbind_ok.shift

          queue.handle_unbind_ok(frame.decode_payload)
        end


        self.handle(Protocol::Queue::PurgeOk) do |connection, frame|
          channel = connection.channels[frame.channel]
          queue   = channel.queues_awaiting_purge_ok.shift

          queue.handle_purge_ok(frame.decode_payload)
        end


        self.handle(Protocol::Basic::GetOk) do |connection, frame, content_frames|
          channel = connection.channels[frame.channel]
          queue   = channel.queues_awaiting_get_response.shift
          method  = frame.decode_payload

          header  = content_frames.shift
          body    = content_frames.map {|frame| frame.payload }.join

          queue.handle_get_ok(method, header, body) if queue
        end


        self.handle(Protocol::Basic::GetEmpty) do |connection, frame|
          channel = connection.channels[frame.channel]
          queue   = channel.queues_awaiting_get_response.shift

          queue.handle_get_empty(frame.decode_payload)
        end
      end # Queue
    end # Async
  end # Client
end # AMQ
