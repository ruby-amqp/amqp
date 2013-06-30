# encoding: utf-8

require "amqp/consumer_tag_generator"

module AMQP
  # AMQP consumers are entities that handle messages delivered to them ("push API" as opposed to "pull API") by AMQP broker.
  # Every consumer is associated with a queue. Consumers can be exclusive (no other consumers can be registered for the same queue)
  # or not (consumers share the queue). In the case of multiple consumers per queue, messages are distributed in round robin
  # manner with respect to channel-level prefetch setting).
  #
  # @see AMQP::Queue
  # @see AMQP::Queue#subscribe
  # @see AMQP::Queue#cancel
  class Consumer

    #
    # Behaviours
    #

    include Callbacks
    extend  ProtocolMethodHandlers


    #
    # API
    #

    # @return [AMQP::Channel] Channel this consumer uses
    attr_reader :channel
    # @return [AMQP::Queue] Queue messages are consumed from
    attr_reader :queue
    # @return [String] Consumer tag, unique consumer identifier
    attr_reader :consumer_tag
    # @return [Hash] Custom subscription metadata
    attr_reader :arguments


    # @return [AMQP::ConsumerTagGenerator] Consumer tag generator
    def self.tag_generator
      @tag_generator ||= AMQP::ConsumerTagGenerator.new
    end # self.tag_generator

    # @param [AMQP::ConsumerTagGenerator] Assigns consumer tag generator that will be used by consumer instances
    # @return [AMQP::ConsumerTagGenerator] Provided argument
    def self.tag_generator=(generator)
      @tag_generator = generator
    end


    def initialize(channel, queue, consumer_tag = nil, exclusive = false, no_ack = false, arguments = {}, no_local = false, &block)
      @callbacks    = Hash.new

      @channel       = channel            || raise(ArgumentError, "channel is nil")
      @connection    = channel.connection || raise(ArgumentError, "connection is nil")
      @queue         = queue        || raise(ArgumentError, "queue is nil")
      @consumer_tag  = consumer_tag || self.class.tag_generator.generate_for(queue)
      @exclusive     = exclusive
      @no_ack        = no_ack
      @arguments     = arguments

      @no_local     = no_local

      self.register_with_channel
      self.register_with_queue
    end # initialize

    # @return [Boolean] true if this consumer is exclusive (other consumers for the same queue are not allowed)
    def exclusive?
      !!@exclusive
    end # exclusive?



    # Begin consuming messages from the queue
    # @return [AMQP::Consumer] self
    def consume(nowait = false, &block)
      @channel.once_open do
        @queue.once_declared do
          @connection.send_frame(AMQ::Protocol::Basic::Consume.encode(@channel.id, @queue.name, @consumer_tag, @no_local, @no_ack, @exclusive, nowait, @arguments))
          self.redefine_callback(:consume, &block)

          @channel.consumers_awaiting_consume_ok.push(self)

          self
        end
      end

      self
    end # consume(nowait = false, &block)

    # Used by automatic recovery code.
    # @api plugin
    # @return [AMQP::Consumer] self
    def resubscribe(&block)
      @channel.once_open do
        @queue.once_declared do
          self.unregister_with_channel
          @consumer_tag = self.class.tag_generator.generate_for(@queue)
          self.register_with_channel

          @connection.send_frame(AMQ::Protocol::Basic::Consume.encode(@channel.id, @queue.name, @consumer_tag, @no_local, @no_ack, @exclusive, block.nil?, @arguments))
          self.redefine_callback(:consume, &block) if block

          self
        end
      end

      self
    end # resubscribe(&block)

    # @return [AMQP::Consumer] self
    def cancel(nowait = false, &block)
      @channel.once_open do
        @queue.once_declared do
          @connection.send_frame(AMQ::Protocol::Basic::Cancel.encode(@channel.id, @consumer_tag, nowait))
          self.clear_callbacks(:delivery)
          self.clear_callbacks(:consume)
          self.clear_callbacks(:scancel)

          self.unregister_with_channel
          self.unregister_with_queue

          if !nowait
            self.redefine_callback(:cancel, &block)
            @channel.consumers_awaiting_cancel_ok.push(self)
          end

          self
        end
      end

      self
    end # cancel(nowait = false, &block)

    # {AMQP::Queue} API compatibility.
    #
    # @return [Boolean] true if this consumer is active (subscribed for message delivery)
    # @api public
    def subscribed?
      !@callbacks[:delivery].empty?
    end # subscribed?

    # Legacy {AMQP::Queue} API compatibility.
    # @private
    # @deprecated
    def callback
      if @callbacks[:delivery]
        @callbacks[:delivery].first
      end
    end # callback


    # Register a block that will be used to handle delivered messages.
    #
    # @return [AMQP::Consumer] self
    # @see AMQP::Queue#subscribe
    def on_delivery(&block)
      # We have to maintain this multiple arities jazz
      # because older versions this gem are used in examples in at least 3
      # books published by O'Reilly :(. MK.
      delivery_shim = Proc.new { |basic_deliver, headers, payload|
        case block.arity
        when 1 then
          block.call(payload)
        when 2 then
          h = Header.new(@channel, basic_deliver, headers.decode_payload)
          block.call(h, payload)
        else
          h = Header.new(@channel, basic_deliver, headers.decode_payload)
          block.call(h, payload, basic_deliver.consumer_tag, basic_deliver.delivery_tag, basic_deliver.redelivered, basic_deliver.exchange, basic_deliver.routing_key)
        end
      }

      self.append_callback(:delivery, &delivery_shim)

      self
    end # on_delivery(&block)


    # @return [String] Readable representation of relevant object state.
    def inspect
      "#<AMQP::Consumer:#{@consumer_tag}> queue=#{@queue.name} channel=#{@channel.id} callbacks=#{@callbacks.inspect}"
    end # inspect


    def on_cancel(&block)
      self.append_callback(:scancel, &block)

      self
    end # on_cancel(&block)

    def handle_cancel(basic_cancel)
      self.exec_callback(:scancel, basic_cancel)
    end # handle_cancel(basic_cancel)



    # @group Acknowledging & Rejecting Messages

    # Acknowledge a delivery tag.
    # @return [Consumer]  self
    #
    # @api public
    # @see http://bit.ly/htCzCX AMQP 0.9.1 protocol documentation (Section 1.8.3.13.)
    def acknowledge(delivery_tag)
      @channel.acknowledge(delivery_tag)

      self
    end # acknowledge(delivery_tag)

    #
    # @return [Consumer]  self
    #
    # @api public
    # @see http://bit.ly/htCzCX AMQP 0.9.1 protocol documentation (Section 1.8.3.14.)
    def reject(delivery_tag, requeue = true)
      @channel.reject(delivery_tag, requeue)

      self
    end # reject(delivery_tag, requeue = true)

    # Defines a callback that will be executed when AMQP connection is recovered after a network failure..
    # Only one callback can be defined (the one defined last replaces previously added ones).
    #
    # @api public
    # Defines a callback that will be executed when AMQP connection is recovered after a network failure..
    # Only one callback can be defined (the one defined last replaces previously added ones).
    #
    # @api public
    def on_recovery(&block)
      self.redefine_callback(:after_recovery, &block)
    end # on_recovery(&block)
    alias after_recovery on_recovery

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

    # @private
    def run_after_recovery_callbacks
      self.exec_callback_yielding_self(:after_recovery)
    end



    # Called by associated connection object when AMQP connection has been re-established
    # (for example, after a network failure).
    #
    # @api plugin
    def auto_recover
      self.exec_callback_yielding_self(:before_recovery)
      self.resubscribe
      self.exec_callback_yielding_self(:after_recovery)
    end # auto_recover

    # @endgroup


    def to_s
      "#<#{self.class.name} @consumer_tag=#{@consumer_tag} @queue=#{@queue.name} @channel=#{@channel.id}>"
    end


    #
    # Implementation
    #

    def handle_delivery(basic_deliver, metadata, payload)
      self.exec_callback(:delivery, basic_deliver, metadata, payload)
    end # handle_delivery(basic_deliver, metadata, payload)

    def handle_consume_ok(consume_ok)
      self.exec_callback_once(:consume, consume_ok)
    end # handle_consume_ok(consume_ok)

    def handle_cancel_ok(cancel_ok)
      @consumer_tag = nil

      # detach from object graph so that this object will be garbage-collected
      @queue        = nil
      @channel      = nil
      @connection   = nil

      self.exec_callback_once(:cancel, cancel_ok)
    end # handle_cancel_ok(method)



    self.handle(AMQ::Protocol::Basic::ConsumeOk) do |connection, frame|
      channel  = connection.channels[frame.channel]
      consumer = channel.consumers_awaiting_consume_ok.shift

      consumer.handle_consume_ok(frame.decode_payload)
    end


    self.handle(AMQ::Protocol::Basic::CancelOk) do |connection, frame|
      channel  = connection.channels[frame.channel]
      consumer = channel.consumers_awaiting_cancel_ok.shift

      consumer.handle_cancel_ok(frame.decode_payload)
    end


    self.handle(AMQ::Protocol::Basic::Deliver) do |connection, method_frame, content_frames|
      channel       = connection.channels[method_frame.channel]
      basic_deliver = method_frame.decode_payload
      consumer      = channel.consumers[basic_deliver.consumer_tag]

      metadata = content_frames.shift
      payload  = content_frames.map { |frame| frame.payload }.join

      # Handle the delivery only if the consumer still exists.
      # The broker has been known to deliver a few messages after the consumer has been shut down.
      consumer.handle_delivery(basic_deliver, metadata, payload) if consumer
    end


    protected

    def register_with_channel
      @channel.consumers[@consumer_tag] = self
    end # register_with_channel

    def register_with_queue
      @queue.consumers[@consumer_tag]   = self
    end # register_with_queue

    def unregister_with_channel
      @channel.consumers.delete(@consumer_tag)
    end # register_with_channel

    def unregister_with_queue
      @queue.consumers.delete(@consumer_tag)
    end # register_with_queue

    handle(AMQ::Protocol::Basic::Cancel) do |connection, method_frame|
      channel      = connection.channels[method_frame.channel]
      basic_cancel = method_frame.decode_payload
      consumer     = channel.consumers[basic_cancel.consumer_tag]

      # Handle the delivery only if the consumer still exists.
      consumer.handle_cancel(basic_cancel) if consumer
    end
  end # Consumer
end # AMQP
