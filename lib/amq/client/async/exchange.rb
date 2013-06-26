# encoding: utf-8

require "amq/client/exceptions"
require "amq/client/entity"
require "amq/client/server_named_entity"

module AMQ
  module Client
    module Async
      class Exchange


        include Entity
        include ServerNamedEntity
        extend ProtocolMethodHandlers

        BUILTIN_TYPES = [:fanout, :direct, :topic, :headers].freeze



        #
        # API
        #

        # Channel this exchange belongs to.
        attr_reader :channel

        # Exchange name. May be server-generated or assigned directly.
        # @return [String]
        attr_reader :name

        # @return [Symbol] One of :direct, :fanout, :topic, :headers
        attr_reader :type

        # @return [Hash] Additional arguments given on queue declaration. Typically used by AMQP extensions.
        attr_reader :arguments



        def initialize(connection, channel, name, type = :fanout)
          if !(BUILTIN_TYPES.include?(type.to_sym) || type.to_s =~ /^x-.+/i)
            raise UnknownExchangeTypeError.new(BUILTIN_TYPES, type)
          end

          @connection = connection
          @channel    = channel
          @name       = name
          @type       = type

          # register pre-declared exchanges
          if @name == AMQ::Protocol::EMPTY_STRING || @name =~ /^amq\.(direct|fanout|topic|match|headers)/
            @channel.register_exchange(self)
          end

          super(connection)
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


        # @group Declaration

        # @api public
        def declare(passive = false, durable = false, auto_delete = false, nowait = false, arguments = nil, &block)
          # for re-declaration
          @passive     = passive
          @durable     = durable
          @auto_delete = auto_delete
          @arguments   = arguments

          @connection.send_frame(Protocol::Exchange::Declare.encode(@channel.id, @name, @type.to_s, passive, durable, auto_delete, false, nowait, arguments))

          unless nowait
            self.define_callback(:declare, &block)
            @channel.exchanges_awaiting_declare_ok.push(self)
          end

          self
        end


        # @api public
        def redeclare(&block)
          nowait = block.nil?
          @connection.send_frame(Protocol::Exchange::Declare.encode(@channel.id, @name, @type.to_s, @passive, @durable, @auto_delete, false, nowait, @arguments))

          unless nowait
            self.define_callback(:declare, &block)
            @channel.exchanges_awaiting_declare_ok.push(self)
          end

          self
        end # redeclare(&block)

        # @endgroup


        # @api public
        def delete(if_unused = false, nowait = false, &block)
          @connection.send_frame(Protocol::Exchange::Delete.encode(@channel.id, @name, if_unused, nowait))

          unless nowait
            self.define_callback(:delete, &block)

            # TODO: delete itself from exchanges cache
            @channel.exchanges_awaiting_delete_ok.push(self)
          end

          self
        end # delete(if_unused = false, nowait = false)



        # @group Publishing Messages

        # @api public
        def publish(payload, routing_key = AMQ::Protocol::EMPTY_STRING, user_headers = {}, mandatory = false, immediate = false, frame_size = nil)
          headers = { :priority => 0, :delivery_mode => 2, :content_type => "application/octet-stream" }.merge(user_headers)
          @connection.send_frameset(Protocol::Basic::Publish.encode(@channel.id, payload, headers, @name, routing_key, mandatory, immediate, (frame_size || @connection.frame_max)), @channel)

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
          @name = method.exchange if self.anonymous?
          @channel.register_exchange(self)

          self.exec_callback_once_yielding_self(:declare, method)
        end

        def handle_delete_ok(method)
          self.exec_callback_once(:delete, method)
        end # handle_delete_ok(method)



        self.handle(Protocol::Exchange::DeclareOk) do |connection, frame|
          method   = frame.decode_payload
          channel  = connection.channels[frame.channel]
          exchange = channel.exchanges_awaiting_declare_ok.shift

          exchange.handle_declare_ok(method)
        end # handle


        self.handle(Protocol::Exchange::DeleteOk) do |connection, frame|
          channel  = connection.channels[frame.channel]
          exchange = channel.exchanges_awaiting_delete_ok.shift
          exchange.handle_delete_ok(frame.decode_payload)
        end # handle


        self.handle(Protocol::Basic::Return) do |connection, frame, content_frames|
          channel  = connection.channels[frame.channel]
          method   = frame.decode_payload
          exchange = channel.find_exchange(method.exchange)

          header   = content_frames.shift
          body     = content_frames.map { |frame| frame.payload }.join

          exchange.exec_callback(:return, method, header, body)
        end

      end # Exchange
    end # Async
  end # Client
end # AMQ
