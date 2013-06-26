# encoding: utf-8

require "amq/client/logging"
require "amq/client/settings"
require "amq/client/async/auth_mechanism_adapter"
require "amq/client/async/entity"
require "amq/client/async/channel"

module AMQ
  # For overview of AMQP client adapters API, see {AMQ::Client::Adapter}
  module Client
    module Async

      # Base adapter class. Specific implementations (for example, EventMachine-based, Cool.io-based or
      # sockets-based) subclass it and must implement Adapter API methods:
      #
      # * #send_raw(data)
      # * #estabilish_connection(settings)
      # * #close_connection
      #
      # @abstract
      module Adapter

        def self.included(host)
          host.extend ClassMethods
          host.extend ProtocolMethodHandlers

          host.class_eval do

            #
            # API
            #

            attr_accessor :logger
            attr_accessor :settings

            # @return [Array<#call>]
            attr_reader :callbacks


            # The locale defines the language in which the server will send reply texts.
            #
            # @see http://bit.ly/amqp091reference AMQP 0.9.1 protocol reference (Section 1.4.2.2)
            attr_accessor :locale

            # Client capabilities
            #
            # @see http://bit.ly/amqp091reference AMQP 0.9.1 protocol reference (Section 1.4.2.2.1)
            attr_accessor :client_properties

            # Server properties
            #
            # @see http://bit.ly/amqp091reference AMQP 0.9.1 protocol reference (Section 1.4.2.1.3)
            attr_reader :server_properties

            # Server capabilities
            #
            # @see http://bit.ly/amqp091reference AMQP 0.9.1 protocol reference (Section 1.4.2.1.3)
            attr_reader :server_capabilities

            # Locales server supports
            #
            # @see http://bit.ly/amqp091reference AMQP 0.9.1 protocol reference (Section 1.4.2.1.3)
            attr_reader :server_locales

            # Authentication mechanism used.
            #
            # @see http://bit.ly/amqp091reference AMQP 0.9.1 protocol reference (Section 1.4.2.2)
            attr_reader :mechanism

            # Authentication mechanisms broker supports.
            #
            # @see http://bit.ly/amqp091reference AMQP 0.9.1 protocol reference (Section 1.4.2.2)
            attr_reader :server_authentication_mechanisms

            # Channels within this connection.
            #
            # @see http://bit.ly/amqp091spec AMQP 0.9.1 specification (Section 2.2.5)
            attr_reader :channels

            # Maximum channel number that the server permits this connection to use.
            # Usable channel numbers are in the range 1..channel_max.
            # Zero indicates no specified limit.
            #
            # @see http://bit.ly/amqp091reference AMQP 0.9.1 protocol reference (Sections 1.4.2.5.1 and 1.4.2.6.1)
            attr_accessor :channel_max

            # Maximum frame size that the server permits this connection to use.
            #
            # @see http://bit.ly/amqp091reference AMQP 0.9.1 protocol reference (Sections 1.4.2.5.2 and 1.4.2.6.2)
            attr_accessor :frame_max


            attr_reader :known_hosts



            # @api plugin
            # @see #disconnect
            # @note Adapters must implement this method but it is NOT supposed to be used directly.
            #       AMQ protocol defines two-step process of closing connection (send Connection.Close
            #       to the peer and wait for Connection.Close-Ok), implemented by {Adapter#disconnect}
            def close_connection
              raise NotImplementedError
            end unless defined?(:close_connection) # since it is a module, this method may already be defined
          end
        end # self.included(host)



        module ClassMethods
          # Settings
          def settings
            @settings ||= AMQ::Client::Settings.default
          end

          def logger
            @logger ||= begin
                          require "logger"
                          Logger.new(STDERR)
                        end
          end

          def logger=(logger)
            methods = AMQ::Client::Logging::REQUIRED_METHODS
            unless methods.all? { |method| logger.respond_to?(method) }
              raise AMQ::Client::Logging::IncompatibleLoggerError.new(methods)
            end

            @logger = logger
          end

          # @return [Boolean] Current value of logging flag.
          def logging
            settings[:logging]
          end

          # Turns loggin on or off.
          def logging=(boolean)
            settings[:logging] = boolean
          end


          # Establishes connection to AMQ broker and returns it. New connection object is yielded to
          # the block if it is given.
          #
          # @example Specifying adapter via the :adapter option
          #   AMQ::Client::Adapter.connect(:adapter => "socket")
          # @example Specifying using custom adapter class
          #   AMQ::Client::SocketClient.connect
          # @param [Hash] Connection parameters, including :adapter to use.
          # @api public
          def connect(settings = nil, &block)
            @settings = Settings.configure(settings)

            instance = self.new
            instance.establish_connection(settings)
            instance.register_connection_callback(&block)

            instance
          end


          # Can be overriden by higher-level libraries like amqp gem or bunny.
          # Defaults to AMQ::Client::TCPConnectionFailed.
          #
          # @return [Class]
          def tcp_connection_failure_exception_class
            @tcp_connection_failure_exception_class ||= AMQ::Client::TCPConnectionFailed
          end # tcp_connection_failure_exception_class

          # Can be overriden by higher-level libraries like amqp gem or bunny.
          # Defaults to AMQ::Client::PossibleAuthenticationFailure.
          #
          # @return [Class]
          def authentication_failure_exception_class
            @authentication_failure_exception_class ||= AMQ::Client::PossibleAuthenticationFailureError
          end # authentication_failure_exception_class
        end # ClassMethods


        #
        # Behaviors
        #

        include Openable
        include Callbacks


        extend RegisterEntityMixin

        register_entity :channel,  AMQ::Client::Async::Channel


        #
        # API
        #



        # Establish socket connection to the server.
        #
        # @api plugin
        def establish_connection(settings)
          raise NotImplementedError
        end

        # Properly close connection with AMQ broker, as described in
        # section 2.2.4 of the {http://bit.ly/amqp091spec AMQP 0.9.1 specification}.
        #
        # @api  plugin
        # @see  #close_connection
        def disconnect(reply_code = 200, reply_text = "Goodbye", class_id = 0, method_id = 0, &block)
          @intentionally_closing_connection = true
          self.on_disconnection do
            @frames.clear
            block.call if block
          end

          # ruby-amqp/amqp#66, MK.
          if self.open?
            closing!
            self.send_frame(Protocol::Connection::Close.encode(reply_code, reply_text, class_id, method_id))
          elsif self.closing?
            # no-op
          else
            self.disconnection_successful
          end
        end




        # Sends AMQ protocol header (also known as preamble).
        #
        # @note This must be implemented by all AMQP clients.
        # @api plugin
        # @see http://bit.ly/amqp091spec AMQP 0.9.1 specification (Section 2.2)
        def send_preamble
          self.send_raw(AMQ::Protocol::PREAMBLE)
        end

        # Sends frame to the peer, checking that connection is open.
        #
        # @raise [ConnectionClosedError]
        def send_frame(frame)
          if closed?
            raise ConnectionClosedError.new(frame)
          else
            self.send_raw(frame.encode)
          end
        end

        # Sends multiple frames, one by one. For thread safety this method takes a channel
        # object and synchronizes on it.
        #
        # @api public
        def send_frameset(frames, channel)
          # some (many) developers end up sharing channels between threads and when multiple
          # threads publish on the same channel aggressively, at some point frames will be
          # delivered out of order and broker will raise 505 UNEXPECTED_FRAME exception.
          # If we synchronize on the channel, however, this is both thread safe and pretty fine-grained
          # locking. Note that "single frame" methods do not need this kind of synchronization. MK.
          channel.synchronize do
            frames.each { |frame| self.send_frame(frame) }
          end
        end # send_frameset(frames)



        # Returns heartbeat interval this client uses, in seconds.
        # This value may or may not be used depending on broker capabilities.
        # Zero means the server does not want a heartbeat.
        #
        # @return  [Fixnum]  Heartbeat interval this client uses, in seconds.
        # @see http://bit.ly/amqp091reference AMQP 0.9.1 protocol reference (Section 1.4.2.6)
        def heartbeat_interval
          @heartbeat_interval
        end # heartbeat_interval

        # Returns true if heartbeats are enabled (heartbeat interval is greater than 0)
        # @return [Boolean]
        def heartbeats_enabled?
          @heartbeat_interval && (@heartbeat_interval > 0)
        end


        # vhost this connection uses. Default is "/", a historically estabilished convention
        # of RabbitMQ and amqp gem.
        #
        # @return [String] vhost this connection uses
        # @api public
        def vhost
          @settings.fetch(:vhost, "/")
        end # vhost



        # @group Error Handling and Recovery

        # Called when initial TCP connection fails.
        # @api public
        def tcp_connection_failed
          @recovered = false

          @on_tcp_connection_failure.call(@settings) if @on_tcp_connection_failure
        end

        # Called when previously established TCP connection fails.
        # @api public
        def tcp_connection_lost
          @recovered = false

          @on_tcp_connection_loss.call(self, @settings) if @on_tcp_connection_loss
          self.handle_connection_interruption
        end

        # @return [Boolean]
        def reconnecting?
          @reconnecting
        end # reconnecting?


        # Defines a callback that will be run when initial TCP connection fails.
        # You can define only one callback.
        #
        # @api public
        def on_tcp_connection_failure(&block)
          @on_tcp_connection_failure = block
        end

        # Defines a callback that will be run when TCP connection to AMQP broker is lost (interrupted).
        # You can define only one callback.
        #
        # @api public
        def on_tcp_connection_loss(&block)
          @on_tcp_connection_loss = block
        end

        # Defines a callback that will be run when TCP connection is closed before authentication
        # finishes. Usually this means authentication failure. You can define only one callback.
        #
        # @api public
        def on_possible_authentication_failure(&block)
          @on_possible_authentication_failure = block
        end


        # Defines a callback that will be executed when connection is closed after
        # connection-level exception. Only one callback can be defined (the one defined last
        # replaces previously added ones).
        #
        # @api public
        def on_error(&block)
          self.redefine_callback(:error, &block)
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
        # @api plugin
        def handle_connection_interruption
          self.cancel_heartbeat_sender

          @channels.each { |n, c| c.handle_connection_interruption }
          self.exec_callback_yielding_self(:after_connection_interruption)
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
          self.exec_callback_yielding_self(:before_recovery, @settings)

          @channels.each { |n, ch| ch.run_before_recovery_callbacks }
        end


        # Defines a callback that will be executed after AMQP connection has recovered after a network failure..
        # Only one callback can be defined (the one defined last replaces previously added ones).
        #
        # @api public
        def on_recovery(&block)
          self.redefine_callback(:after_recovery, &block)
        end # on_recovery(&block)
        alias after_recovery on_recovery

        # @private
        def run_after_recovery_callbacks
          self.exec_callback_yielding_self(:after_recovery, @settings)

          @channels.each { |n, ch| ch.run_after_recovery_callbacks }
        end


        # @return [Boolean] whether connection is in the automatic recovery mode
        # @api public
        def auto_recovering?
          !!@auto_recovery
        end # auto_recovering?
        alias auto_recovery? auto_recovering?


        # Performs recovery of channels that are in the automatic recovery mode. Does not run recovery
        # callbacks.
        #
        # @see Channel#auto_recover
        # @see Queue#auto_recover
        # @see Exchange#auto_recover
        # @api plugin
        def auto_recover
          @channels.select { |channel_id, ch| ch.auto_recovering? }.each { |n, ch| ch.auto_recover }
        end # auto_recover


        # Performs recovery of channels that are in the automatic recovery mode. "before recovery" callbacks
        # are run immediately, "after recovery" callbacks are run after AMQP connection is re-established and
        # auto recovery is performed (using #auto_recover).
        #
        # Use this method if you want to run automatic recovery process after handling a connection-level exception,
        # for example, 320 CONNECTION_FORCED (used by RabbitMQ when it is shut down gracefully).
        #
        # @see Channel#auto_recover
        # @see Queue#auto_recover
        # @see Exchange#auto_recover
        # @api plugin
        def start_automatic_recovery
          self.run_before_recovery_callbacks
          self.register_connection_callback do
            # always run automatic recovery, because it is per-channel
            # and connection has to start it. Channels that did not opt-in for
            # autorecovery won't be selected. MK.
            self.auto_recover
            self.run_after_recovery_callbacks
          end
        end # start_automatic_recovery


        # Defines a callback that will be executed after time since last broker heartbeat is greater
        # than or equal to the heartbeat interval (skipped heartbeat is detected).
        # Only one callback can be defined (the one defined last replaces previously added ones).
        #
        # @api public
        def on_skipped_heartbeats(&block)
          self.redefine_callback(:skipped_heartbeats, &block)
        end # on_skipped_heartbeats(&block)

        # @private
        def run_skipped_heartbeats_callbacks
          self.exec_callback_yielding_self(:skipped_heartbeats, @settings)
        end

        # @endgroup




        #
        # Implementation
        #


        # Sends opaque data to AMQ broker over active connection.
        #
        # @note This must be implemented by all AMQP clients.
        # @api plugin
        def send_raw(data)
          raise NotImplementedError
        end

        # Sends connection preamble to the broker.
        # @api plugin
        def handshake
          @authenticating = true
          self.send_preamble
        end


        # Sends connection.open to the server.
        #
        # @api plugin
        # @see http://bit.ly/amqp091reference AMQP 0.9.1 protocol reference (Section 1.4.2.7)
        def open(vhost = "/")
          self.send_frame(Protocol::Connection::Open.encode(vhost))
        end

        # Resets connection state.
        #
        # @api plugin
        def reset_state!
          # no-op by default
        end # reset_state!

        # @api plugin
        # @see http://tools.ietf.org/rfc/rfc2595.txt RFC 2595
        def encode_credentials(username, password)
          auth_mechanism_adapter.encode_credentials(username, password)
        end # encode_credentials(username, password)

        # Retrieves an AuthMechanismAdapter that will encode credentials for
        # this Adapter.
        #
        # @api plugin
        def auth_mechanism_adapter
          @auth_mechanism_adapter ||= AuthMechanismAdapter.for_adapter(self)
        end


        # Processes a single frame.
        #
        # @param [AMQ::Protocol::Frame] frame
        # @api plugin
        def receive_frame(frame)
          @frames[frame.channel] ||= Array.new
          @frames[frame.channel] << frame

          if frameset_complete?(@frames[frame.channel])
            receive_frameset(@frames[frame.channel])
            # for channel.close, frame.channel will be nil. MK.
            clear_frames_on(frame.channel) if @frames[frame.channel]
          end
        end

        # Processes a frameset by finding and invoking a suitable handler.
        # Heartbeat frames are treated in a special way: they simply update @last_server_heartbeat
        # value.
        #
        # @param [Array<AMQ::Protocol::Frame>] frames
        # @api plugin
        def receive_frameset(frames)
          if self.heartbeats_enabled?
            # treat incoming traffic as heartbeats.
            # this operation is pretty expensive under heavy traffic but heartbeats can be disabled
            # (and are also disabled by default). MK.
            @last_server_heartbeat = Time.now
          end
          frame = frames.first

          if AMQ::Protocol::HeartbeatFrame === frame
            # no-op
          else
            if callable = AMQ::Client::HandlersRegistry.find(frame.method_class)
              f = frames.shift
              callable.call(self, f, frames)
            else
              raise MissingHandlerError.new(frames.first)
            end
          end
        end

        # Clears frames that were received but not processed on given channel. Needs to be called
        # when the channel is closed.
        # @private
        def clear_frames_on(channel_id)
          raise ArgumentError, "channel id cannot be nil!" if channel_id.nil?

          @frames[channel_id].clear
        end

        # Sends a heartbeat frame if connection is open.
        # @api plugin
        def send_heartbeat
          if tcp_connection_established? && !@handling_skipped_hearbeats && @last_server_heartbeat
            if @last_server_heartbeat < (Time.now - (self.heartbeat_interval * 2)) && !reconnecting?
              logger.error "[amqp] Detected missing server heartbeats"
              self.handle_skipped_hearbeats
            end
            send_frame(Protocol::HeartbeatFrame)
          end
        end # send_heartbeat






        # Handles connection.start.
        #
        # @api plugin
        # @see http://bit.ly/amqp091reference AMQP 0.9.1 protocol reference (Section 1.4.2.1.)
        def handle_start(connection_start)
          @server_properties                = connection_start.server_properties
          @server_capabilities              = @server_properties["capabilities"]

          @server_authentication_mechanisms = (connection_start.mechanisms || "").split(" ")
          @server_locales                   = Array(connection_start.locales)

          username = @settings[:user] || @settings[:username]
          password = @settings[:pass] || @settings[:password]

          # It's not clear whether we should transition to :opening state here
          # or in #open but in case authentication fails, it would be strange to have
          # @status undefined. So lets do this. MK.
          opening!

          self.send_frame(Protocol::Connection::StartOk.encode(@client_properties, mechanism, self.encode_credentials(username, password), @locale))
        end


        # Handles Connection.Tune-Ok.
        #
        # @api plugin
        # @see http://bit.ly/amqp091reference AMQP 0.9.1 protocol reference (Section 1.4.2.6)
        def handle_tune(connection_tune)
          @channel_max        = connection_tune.channel_max.freeze
          @frame_max          = connection_tune.frame_max.freeze

          client_heartbeat    = @settings[:heartbeat] || @settings[:heartbeat_interval] || 0

          @heartbeat_interval = negotiate_heartbeat_value(client_heartbeat, connection_tune.heartbeat)

          self.send_frame(Protocol::Connection::TuneOk.encode(@channel_max, [settings[:frame_max], @frame_max].min, @heartbeat_interval))
          self.initialize_heartbeat_sender if heartbeats_enabled?
        end # handle_tune(method)


        # Handles Connection.Open-Ok.
        #
        # @api plugin
        # @see http://bit.ly/amqp091reference AMQP 0.9.1 protocol reference (Section 1.4.2.8.)
        def handle_open_ok(open_ok)
          @known_hosts = open_ok.known_hosts.dup.freeze

          opened!
          self.connection_successful if self.respond_to?(:connection_successful)
        end


        # Handles connection.close. When broker detects a connection level exception, this method is called.
        #
        # @api plugin
        # @see http://bit.ly/amqp091reference AMQP 0.9.1 protocol reference (Section 1.5.2.9)
        def handle_close(conn_close)
          closed!
          self.exec_callback_yielding_self(:error, conn_close)
        end


        # Handles Connection.Close-Ok.
        #
        # @api plugin
        # @see http://bit.ly/amqp091reference AMQP 0.9.1 protocol reference (Section 1.4.2.10)
        def handle_close_ok(close_ok)
          closed!
          self.disconnection_successful
        end # handle_close_ok(close_ok)



        protected

        def negotiate_heartbeat_value(client_value, server_value)
          if client_value == 0 || server_value == 0
            [client_value, server_value].max
          else
            [client_value, server_value].min
          end
        end

        # Returns next frame from buffer whenever possible
        #
        # @api private
        def get_next_frame
          return nil unless @chunk_buffer.size > 7 # otherwise, cannot read the length
          # octet + short
          offset = 3 # 1 + 2
          # length
          payload_length = @chunk_buffer[offset, 4].unpack(AMQ::Protocol::PACK_UINT32).first
          # 4 bytes for long payload length, 1 byte final octet
          frame_length = offset + payload_length + 5
          if frame_length <= @chunk_buffer.size
            @chunk_buffer.slice!(0, frame_length)
          else
            nil
          end
        end # def get_next_frame

        # Utility methods

        # Determines, whether the received frameset is ready to be further processed
        def frameset_complete?(frames)
          return false if frames.empty?
          first_frame = frames[0]
          first_frame.final? || (first_frame.method_class.has_content? && content_complete?(frames[1..-1]))
        end

        # Determines, whether given frame array contains full content body
        def content_complete?(frames)
          return false if frames.empty?
          header = frames[0]
          raise "Not a content header frame first: #{header.inspect}" unless header.kind_of?(AMQ::Protocol::HeaderFrame)
          header.body_size == frames[1..-1].inject(0) {|sum, frame| sum + frame.payload.size }
        end

      end # Adapter

    end # Async
  end # Client
end # AMQ
