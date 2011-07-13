# encoding: utf-8

require "amq/client/async/consumer"

module AMQP
  # AMQP consumers are entities that handle messages delivered to them ("push API" as opposed to "pull API") by AMQP broker.
  # Every consumer is associated with a queue. Consumers can be exclusive (no other consumers can be registered for the same queue)
  # or not (consumers share the queue). In the case of multiple consumers per queue, messages are distributed in round robin
  # manner with respect to channel-level prefetch setting).
  #
  # @see AMQP::Queue
  # @see AMQP::Queue#subscribe
  # @see AMQP::Queue#cancel
  class Consumer < AMQ::Client::Async::Consumer

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


    # @return [AMQ::Client::ConsumerTagGenerator] Consumer tag generator
    def self.tag_generator
      @tag_generator ||= AMQ::Client::ConsumerTagGenerator.new
    end # self.tag_generator

    # @param [AMQ::Client::ConsumerTagGenerator] Assigns consumer tag generator that will be used by consumer instances
    # @return [AMQ::Client::ConsumerTagGenerator] Provided argument
    def self.tag_generator=(generator)
      @tag_generator = generator
    end


    def initialize(channel, queue, consumer_tag = nil, exclusive = false, no_ack = false, arguments = {}, no_local = false)
      super(channel, queue, (consumer_tag || self.class.tag_generator.generate_for(queue)), exclusive, no_ack, arguments, no_local)
    end # initialize

    # @return [Boolean] true if this consumer is exclusive (other consumers for the same queue are not allowed)
    def exclusive?
      super
    end # exclusive?



    # Begin consuming messages from the queue
    # @return [AMQP::Consumer] self
    def consume(nowait = false, &block)
      @channel.once_open do
        @queue.once_declared do
          super(nowait, &block)
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

          super(&block)
        end
      end

      self
    end # resubscribe(&block)

    # @return [AMQP::Consumer] self
    def cancel(nowait = false, &block)
      @channel.once_open do
        @queue.once_declared do
          super(nowait, &block)
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

      super(&delivery_shim)
    end # on_delivery(&block)


    # @group Acknowledging & Rejecting Messages

    # Acknowledge a delivery tag.
    # @return [Consumer]  self
    #
    # @api public
    # @see http://bit.ly/htCzCX AMQP 0.9.1 protocol documentation (Section 1.8.3.13.)
    def acknowledge(delivery_tag)
      super(delivery_tag)
    end # acknowledge(delivery_tag)

    #
    # @return [Consumer]  self
    #
    # @api public
    # @see http://bit.ly/htCzCX AMQP 0.9.1 protocol documentation (Section 1.8.3.14.)
    def reject(delivery_tag, requeue = true)
      super(delivery_tag, requeue)
    end # reject(delivery_tag, requeue = true)

    # @endgroup


    # @group Error Handling & Recovery

    # Defines a callback that will be executed after TCP connection is interrupted (typically because of a network failure).
    # Only one callback can be defined (the one defined last replaces previously added ones).
    #
    # @api public
    def on_connection_interruption(&block)
      super(&block)
    end # on_connection_interruption(&block)
    alias after_connection_interruption on_connection_interruption


    # Defines a callback that will be executed after TCP connection is recovered after a network failure
    # but before AMQP connection is re-opened.
    # Only one callback can be defined (the one defined last replaces previously added ones).
    #
    # @api public
    def before_recovery(&block)
      super(&block)
    end # before_recovery(&block)

    # Defines a callback that will be executed when AMQP connection is recovered after a network failure..
    # Only one callback can be defined (the one defined last replaces previously added ones).
    #
    # @api public
    def on_recovery(&block)
      super(&block)
    end # on_recovery(&block)
    alias after_recovery on_recovery


    # Called by associated connection object when AMQP connection has been re-established
    # (for example, after a network failure).
    #
    # @api plugin
    def auto_recover
      super
    end # auto_recover

    # @endgroup


    # @return [String] Readable representation of relevant object state.
    def inspect
      "#<AMQP::Consumer:#{@consumer_tag}> queue=#{@queue.name} channel=#{@channel.id} callbacks=#{@callbacks.inspect}"
    end # inspect


  end # Consumer
end # AMQP
