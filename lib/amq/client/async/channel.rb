# encoding: utf-8

require "amq/client/async/entity"
require "amq/client/queue"
require "amq/client/exchange"

module AMQ
  module Client
    module Async
      class Channel

        #
        # Behaviours
        #

        extend RegisterEntityMixin
        include Entity
        extend ProtocolMethodHandlers

        register_entity :queue,    AMQ::Client::Queue
        register_entity :exchange, AMQ::Client::Exchange

        #
        # API
        #


        DEFAULT_REPLY_TEXT = "Goodbye".freeze

        attr_reader :id

        attr_reader :exchanges_awaiting_declare_ok, :exchanges_awaiting_delete_ok
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


        def initialize(connection, id, options = {})
          super(connection)

          @id        = id
          @exchanges = Hash.new
          @queues    = Hash.new
          @consumers = Hash.new
          @options       = { :auto_recovery => connection.auto_recovering? }.merge(options)
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

          if channel_max != 0 && !(0..channel_max).include?(id)
            raise ArgumentError.new("Max channel for the connection is #{channel_max}, given: #{id}")
          end
        end

        # @return [Boolean] true if this channel uses automatic recovery mode
        def auto_recovering?
          @auto_recovery
        end # auto_recovering?


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
        # @return [AMQ::Client::Connection] Connection this channel belongs to.
        def connection
          @connection
        end # connection

        # Synchronizes given block using this channel's mutex.
        # @api public
        def synchronize(&block)
          @mutex.synchronize(&block)
        end


        # @group Channel lifecycle

        # Opens AMQP channel.
        #
        # @api public
        def open(&block)
          @connection.send_frame(Protocol::Channel::Open.encode(@id, AMQ::Protocol::EMPTY_STRING))
          @connection.channels[@id] = self
          self.status = :opening

          self.redefine_callback :open, &block
        end
        alias reopen open

        # Closes AMQP channel.
        #
        # @api public
        def close(reply_code = 200, reply_text = DEFAULT_REPLY_TEXT, class_id = 0, method_id = 0, &block)
          @connection.send_frame(Protocol::Channel::Close.encode(@id, reply_code, reply_text, class_id, method_id))

          self.redefine_callback :close, &block
        end

        # @endgroup



        # @group Message acknowledgements

        # Acknowledge one or all messages on the channel.
        #
        # @api public
        # @see files.travis-ci.org/docs/amqp/0.9.1/AMQP091Reference.pdf AMQP 0.9.1 protocol reference (Section 1.8.3.13.)
        def acknowledge(delivery_tag, multiple = false)
          @connection.send_frame(Protocol::Basic::Ack.encode(self.id, delivery_tag, multiple))

          self
        end # acknowledge(delivery_tag, multiple = false)

        # Reject a message with given delivery tag. When rejecting multiple messages at once,
        # uses back.nack instead of basic.reject.
        #
        # @api public
        # @see http://www.rabbitmq.com/amqp-0-9-1-quickref.html#basic.nack
        def reject(delivery_tag, requeue = true, multi = false)
          if multi
            @connection.send_frame(Protocol::Basic::Nack.encode(self.id, delivery_tag, multi, requeue))
          else
            @connection.send_frame(Protocol::Basic::Reject.encode(self.id, delivery_tag, requeue))
          end

          self
        end # reject

        # Notifies AMQ broker that consumer has recovered and unacknowledged messages need
        # to be redelivered.
        #
        # @return [Channel]  self
        #
        # @note RabbitMQ as of 2.3.1 does not support basic.recover with requeue = false.
        # @see files.travis-ci.org/docs/amqp/0.9.1/AMQP091Reference.pdf AMQP 0.9.1 protocol reference (Section 1.8.3.16.)
        # @api public
        def recover(requeue = true, &block)
          @connection.send_frame(Protocol::Basic::Recover.encode(@id, requeue))

          self.redefine_callback :recover, &block
          self
        end # recover(requeue = false, &block)

        # @endgroup



        # @group QoS and flow handling

        # Requests a specific quality of service. The QoS can be specified for the current channel
        # or for all channels on the connection.
        #
        # @note RabbitMQ as of 2.3.1 does not support prefetch_size.
        # @api public
        def qos(prefetch_size = 0, prefetch_count = 32, global = false, &block)
          @connection.send_frame(Protocol::Basic::Qos.encode(@id, prefetch_size, prefetch_count, global))

          self.redefine_callback :qos, &block
          self
        end # qos

        # Asks the peer to pause or restart the flow of content data sent to a consumer.
        # This is a simple flow­control mechanism that a peer can use to avoid overflowing its
        # queues or otherwise finding itself receiving more messages than it can process. Note that
        # this method is not intended for window control. It does not affect contents returned to
        # Queue#get callers.
        #
        # @param [Boolean] active Desired flow state.
        #
        # @see files.travis-ci.org/docs/amqp/0.9.1/AMQP091Reference.pdf AMQP 0.9.1 protocol reference (Section 1.5.2.3.)
        # @api public
        def flow(active = false, &block)
          @connection.send_frame(Protocol::Channel::Flow.encode(@id, active))

          self.redefine_callback :flow, &block
          self
        end # flow(active = false, &block)

        # @return [Boolean]  True if flow in this channel is active (messages will be delivered to consumers that use this channel).
        #
        # @api public
        def flow_is_active?
          @flow_is_active
        end # flow_is_active?

        # @endgroup



        # @group Transactions

        # Sets the channel to use standard transactions. One must use this method at least
        # once on a channel before using #tx_tommit or tx_rollback methods.
        #
        # @api public
        def tx_select(&block)
          @connection.send_frame(Protocol::Tx::Select.encode(@id))

          self.redefine_callback :tx_select, &block
          self
        end # tx_select(&block)

        # Commits AMQP transaction.
        #
        # @api public
        def tx_commit(&block)
          @connection.send_frame(Protocol::Tx::Commit.encode(@id))

          self.redefine_callback :tx_commit, &block
          self
        end # tx_commit(&block)

        # Rolls AMQP transaction back.
        #
        # @api public
        def tx_rollback(&block)
          @connection.send_frame(Protocol::Tx::Rollback.encode(@id))

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
          @queues.each    { |name, q| q.handle_connection_interruption(method) }
          @exchanges.each { |name, e| e.handle_connection_interruption(method) }

          self.exec_callback_yielding_self(:after_connection_interruption)
          self.reset_state!
        end # handle_connection_interruption


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


        # Called by associated connection object when AMQP connection has been re-established
        # (for example, after a network failure).
        #
        # @api plugin
        def auto_recover
          return unless auto_recovering?

          self.open do
            # exchanges must be recovered first because queue recovery includes recovery of bindings. MK.
            @exchanges.each { |name, e| e.auto_recover }
            @queues.each    { |name, q| q.auto_recover }
          end
        end # auto_recover

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

        # Turn on confirmations for this channel and, if given,
        # register callback for Confirm.Select-Ok.
        #
        # @raise [RuntimeError] Occurs when confirmations are already activated.
        # @raise [RuntimeError] Occurs when nowait is true and block is given.
        #
        # @param [Boolean] nowait Whether we expect Confirm.Select-Ok to be returned by the broker or not.
        # @yield [method] Callback which will be executed once we receive Confirm.Select-Ok.
        # @yieldparam [AMQ::Protocol::Confirm::SelectOk] method Protocol method class instance.
        #
        # @return [self] self.
        #
        # @see #confirm
        def confirm_select(nowait = false, &block)
          if nowait && block
            raise ArgumentError, "confirm.select with nowait = true and a callback makes no sense"
          end

          @uses_publisher_confirmations = true
          reset_publisher_index!

          self.redefine_callback(:confirm_select, &block) unless nowait
          self.redefine_callback(:after_publish) do
            increment_publisher_index!
          end
          @connection.send_frame(Protocol::Confirm::Select.encode(@id, nowait))

          self
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
          self.use_publisher_confirmations! unless self.uses_publisher_confirmations?

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
        # @return [AMQ::Client::Exchange] Exchange (if found)
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
        end

        # @api plugin
        # @private
        def handle_close(channel_close)
          self.status = :closed
          self.connection.clear_frames_on(self.id)

          self.exec_callback_yielding_self(:error, channel_close)
        end



        self.handle(Protocol::Channel::OpenOk) do |connection, frame|
          channel = connection.channels[frame.channel]
          channel.handle_open_ok(frame.decode_payload)
        end

        self.handle(Protocol::Channel::CloseOk) do |connection, frame|
          method   = frame.decode_payload
          channels = connection.channels

          channel  = channels[frame.channel]
          channels.delete(channel)
          channel.handle_close_ok(method)
        end

        self.handle(Protocol::Channel::Close) do |connection, frame|
          method   = frame.decode_payload
          channels = connection.channels
          channel  = channels[frame.channel]
          connection.send_frame(Protocol::Channel::CloseOk.encode(frame.channel))
          channel.handle_close(method)
        end

        self.handle(Protocol::Basic::QosOk) do |connection, frame|
          channel = connection.channels[frame.channel]
          channel.exec_callback(:qos, frame.decode_payload)
        end

        self.handle(Protocol::Basic::RecoverOk) do |connection, frame|
          channel = connection.channels[frame.channel]
          channel.exec_callback(:recover, frame.decode_payload)
        end

        self.handle(Protocol::Channel::FlowOk) do |connection, frame|
          channel  = connection.channels[frame.channel]
          method   = frame.decode_payload

          channel.flow_is_active = method.active
          channel.exec_callback(:flow, method)
        end

        self.handle(Protocol::Tx::SelectOk) do |connection, frame|
          channel = connection.channels[frame.channel]
          channel.exec_callback(:tx_select, frame.decode_payload)
        end

        self.handle(Protocol::Tx::CommitOk) do |connection, frame|
          channel = connection.channels[frame.channel]
          channel.exec_callback(:tx_commit, frame.decode_payload)
        end

        self.handle(Protocol::Tx::RollbackOk) do |connection, frame|
          channel = connection.channels[frame.channel]
          channel.exec_callback(:tx_rollback, frame.decode_payload)
        end

        self.handle(Protocol::Confirm::SelectOk) do |connection, frame|
          method  = frame.decode_payload
          channel = connection.channels[frame.channel]
          channel.handle_select_ok(method)
        end

        self.handle(Protocol::Basic::Ack) do |connection, frame|
          method  = frame.decode_payload
          channel = connection.channels[frame.channel]
          channel.handle_basic_ack(method)
        end

        self.handle(Protocol::Basic::Nack) do |connection, frame|
          method  = frame.decode_payload
          channel = connection.channels[frame.channel]
          channel.handle_basic_nack(method)
        end
      end # Channel
    end # Async
  end # Client
end # AMQ
