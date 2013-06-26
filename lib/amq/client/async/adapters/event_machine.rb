# encoding: utf-8

require "eventmachine"
require "amq/client"
require "amq/client/async/adapter"
require "amq/client/framing/string/frame"

module AMQ
  module Client
    module Async
      class EventMachineClient < EM::Connection

        #
        # Behaviours
        #

        include AMQ::Client::Async::Adapter


        #
        # API
        #

        # @group Connection operations

        # Initiates connection to AMQP broker. If callback is given, runs it when (and if) AMQP connection
        # succeeds.
        #
        # @option settings [String] :host ("127.0.0.1") Hostname AMQ broker runs on.
        # @option settings [String] :port (5672) Port AMQ broker listens on.
        # @option settings [String] :vhost ("/") Virtual host to use.
        # @option settings [String] :user ("guest") Username to use for authentication.
        # @option settings [String] :pass ("guest") Password to use for authentication.
        # @option settings [String] :auth_mechanism ("PLAIN") SASL authentication mechanism to use.
        # @option settings [String] :ssl (false) Should be use TLS (SSL) for connection?
        # @option settings [String] :timeout (nil) Connection timeout.
        # @option settings [Fixnum] :heartbeat (0) Connection heartbeat, in seconds.
        # @option settings [Fixnum] :frame_max (131072) Maximum frame size to use. If broker cannot support frames this large, broker's maximum value will be used instead.
        #
        # @param [Hash] settings
        def self.connect(settings = {}, &block)
          @settings = Settings.configure(settings)

          instance = EventMachine.connect(@settings[:host], @settings[:port], self, @settings)
          instance.register_connection_callback(&block)

          instance
        end

        # Reconnect after a period of wait.
        #
        # @param [Fixnum]  period Period of time, in seconds, to wait before reconnection attempt.
        # @param [Boolean] force  If true, enforces immediate reconnection.
        # @api public
        def reconnect(force = false, period = 5)
          if @reconnecting and not force
            EventMachine::Timer.new(period) {
              reconnect(true, period)
            }
            return
          end

          if !@reconnecting
            @reconnecting = true
            self.reset
          end

          EventMachine.reconnect(@settings[:host], @settings[:port], self)
        end

        # Similar to #reconnect, but uses different connection settings
        # @see #reconnect
        # @api public
        def reconnect_to(settings, period = 5)
          if !@reconnecting
            @reconnecting = true
            self.reset
          end

          @settings = Settings.configure(settings)
          EventMachine.reconnect(@settings[:host], @settings[:port], self)
        end


        # Periodically try to reconnect.
        #
        # @param [Fixnum]  period Period of time, in seconds, to wait before reconnection attempt.
        # @param [Boolean] force  If true, enforces immediate reconnection.
        # @api public
        def periodically_reconnect(period = 5)
          @reconnecting = true
          self.reset

          @periodic_reconnection_timer = EventMachine::PeriodicTimer.new(period) {
            EventMachine.reconnect(@settings[:host], @settings[:port], self)
          }
        end

        # @endgroup




        # Defines a callback that will be executed when AMQP connection is considered open:
        # client and broker has agreed on max channel identifier and maximum allowed frame
        # size and authentication succeeds. You can define more than one callback.
        #
        # @see on_possible_authentication_failure
        # @api public
        def on_open(&block)
          @connection_deferrable.callback(&block)
        end # on_open(&block)
        alias on_connection on_open

        # Defines a callback that will be run when broker confirms connection termination
        # (client receives connection.close-ok). You can define more than one callback.
        #
        # @api public
        def on_closed(&block)
          @disconnection_deferrable.callback(&block)
        end # on_closed(&block)
        alias on_disconnection on_closed

        # @see #on_open
        # @private
        def register_connection_callback(&block)
          unless block.nil?
            # delay calling block we were given till after we receive
            # connection.open-ok. Connection will notify us when
            # that happens.
            self.on_open do
              block.call(self)
            end
          end
        end




        def initialize(*args)
          super(*args)

          self.logger   = self.class.logger

          # channel => collected frames. MK.
          @frames            = Hash.new { Array.new }
          @channels          = Hash.new
          @callbacks         = Hash.new

          opening!

          # track TCP connection state, used to detect initial TCP connection failures.
          @tcp_connection_established       = false
          @tcp_connection_failed            = false
          @intentionally_closing_connection = false

          # EventMachine::Connection's and Adapter's constructors arity
          # make it easier to use *args. MK.
          @settings                           = Settings.configure(args.first)
          @on_tcp_connection_failure          = @settings[:on_tcp_connection_failure] || Proc.new { |settings|
            raise self.class.tcp_connection_failure_exception_class.new(settings)
          }
          @on_possible_authentication_failure = @settings[:on_possible_authentication_failure] || Proc.new { |settings|
            raise self.class.authentication_failure_exception_class.new(settings)
          }

          @mechanism         = @settings.fetch(:auth_mechanism, "PLAIN")
          @locale            = @settings.fetch(:locale, "en_GB")
          @client_properties = Settings.client_properties.merge(@settings.fetch(:client_properties, Hash.new))

          @auto_recovery     = (!!@settings[:auto_recovery])

          self.reset
          self.set_pending_connect_timeout((@settings[:timeout] || 3).to_f) unless defined?(JRUBY_VERSION)
        end # initialize(*args)



        # For EventMachine adapter, this is a no-op.
        # @api public
        def establish_connection(settings)
          # Unfortunately there doesn't seem to be any sane way
          # how to get EventMachine connect to the instance level.
        end

        alias close disconnect



        # Whether we are in authentication state (after TCP connection was estabilished
        # but before broker authenticated us).
        #
        # @return [Boolean]
        # @api public
        def authenticating?
          @authenticating
        end # authenticating?

        # IS TCP connection estabilished and currently active?
        # @return [Boolean]
        # @api public
        def tcp_connection_established?
          @tcp_connection_established
        end # tcp_connection_established?




        #
        # Implementation
        #

        # Backwards compatibility with 0.7.0.a25. MK.
        Deferrable = EventMachine::DefaultDeferrable


        alias send_raw send_data


        # EventMachine reactor callback. Is run when TCP connection is estabilished
        # but before resumption of the network loop. Note that this includes cases
        # when TCP connection has failed.
        # @private
        def post_init
          reset

          # note that upgrading to TLS in #connection_completed causes
          # Erlang SSL app that RabbitMQ relies on to report
          # error on TCP connection <0.1465.0>:{ssl_upgrade_error,"record overflow"}
          # and close TCP connection down. Investigation of this issue is likely
          # to take some time and to not be worth in as long as #post_init
          # works fine. MK.
          upgrade_to_tls_if_necessary
        rescue Exception => error
          raise error
        end # post_init



        # Called by EventMachine reactor once TCP connection is successfully estabilished.
        # @private
        def connection_completed
          # we only can safely set this value here because EventMachine is a lovely piece of
          # software that calls #post_init before #unbind even when TCP connection
          # fails. MK.
          @tcp_connection_established       = true
          @periodic_reconnection_timer.cancel if @periodic_reconnection_timer


          # again, this is because #unbind is called in different situations
          # and there is no easy way to tell initial connection failure
          # from connection loss. Not in EventMachine 0.12.x, anyway. MK.

          if @had_successfully_connected_before
            @recovered = true


            self.start_automatic_recovery
            self.upgrade_to_tls_if_necessary
          end

          # now we can set it. MK.
          @had_successfully_connected_before = true
          @reconnecting                      = false
          @handling_skipped_hearbeats        = false
          @last_server_heartbeat             = Time.now

          self.handshake
        end

        # @private
        def close_connection(*args)
          @intentionally_closing_connection = true

          super(*args)
        end

        # Called by EventMachine reactor when
        #
        # * We close TCP connection down
        # * Our peer closes TCP connection down
        # * There is a network connection issue
        # * Initial TCP connection fails
        # @private
        def unbind(exception = nil)
          if !@tcp_connection_established && !@had_successfully_connected_before && !@intentionally_closing_connection
            @tcp_connection_failed = true
            logger.error "[amqp] Detected TCP connection failure"
            self.tcp_connection_failed
          end

          closing!
          @tcp_connection_established = false

          self.handle_connection_interruption if @reconnecting
          @disconnection_deferrable.succeed

          closed!


          self.tcp_connection_lost if !@intentionally_closing_connection && @had_successfully_connected_before

          # since AMQP spec dictates that authentication failure is a protocol exception
          # and protocol exceptions result in connection closure, check whether we are
          # in the authentication stage. If so, it is likely to signal an authentication
          # issue. Java client behaves the same way. MK.
          if authenticating? && !@intentionally_closing_connection
            @on_possible_authentication_failure.call(@settings) if @on_possible_authentication_failure
          end
        end # unbind


        #
        # EventMachine receives data in chunks, sometimes those chunks are smaller
        # than the size of AMQP frame. That's why you need to add some kind of buffer.
        #
        # @private
        def receive_data(chunk)
          @chunk_buffer << chunk
          while frame = get_next_frame
            self.receive_frame(AMQ::Client::Framing::String::Frame.decode(frame))
          end
        end


        # Called by AMQ::Client::Connection after we receive connection.open-ok.
        # @api public
        def connection_successful
          @authenticating = false
          opened!

          @connection_deferrable.succeed
        end # connection_successful


        # Called by AMQ::Client::Connection after we receive connection.close-ok.
        #
        # @api public
        def disconnection_successful
          @disconnection_deferrable.succeed

          # true for "after writing buffered data"
          self.close_connection(true)
          self.reset
          closed!
        end # disconnection_successful

        # Called when time since last server heartbeat received is greater or equal to the
        # heartbeat interval set via :heartbeat_interval option on connection.
        #
        # @api plugin
        def handle_skipped_hearbeats
          if !@handling_skipped_hearbeats && @tcp_connection_established && !@intentionally_closing_connection
            @handling_skipped_hearbeats = true
            self.cancel_heartbeat_sender

            self.run_skipped_heartbeats_callbacks
          end
        end

        # @private
        def initialize_heartbeat_sender
          @last_server_heartbeat = Time.now
          @heartbeats_timer      = EventMachine::PeriodicTimer.new(self.heartbeat_interval, &method(:send_heartbeat))
        end

        # @private
        def cancel_heartbeat_sender
          @heartbeats_timer.cancel if @heartbeats_timer
        end



        self.handle(Protocol::Connection::Start) do |connection, frame|
          connection.handle_start(frame.decode_payload)
        end

        self.handle(Protocol::Connection::Tune) do |connection, frame|
          connection.handle_tune(frame.decode_payload)

          connection.open(connection.vhost)
        end

        self.handle(Protocol::Connection::OpenOk) do |connection, frame|
          connection.handle_open_ok(frame.decode_payload)
        end

        self.handle(Protocol::Connection::Close) do |connection, frame|
          connection.handle_close(frame.decode_payload)
        end

        self.handle(Protocol::Connection::CloseOk) do |connection, frame|
          connection.handle_close_ok(frame.decode_payload)
        end




        protected


        def reset
          @size      = 0
          @payload   = ""
          @frames    = Array.new

          @chunk_buffer                 = ""
          @connection_deferrable        = EventMachine::DefaultDeferrable.new
          @disconnection_deferrable     = EventMachine::DefaultDeferrable.new

          # used to track down whether authentication succeeded. AMQP 0.9.1 dictates
          # that on authentication failure broker must close TCP connection without sending
          # any more data. This is why we need to explicitly track whether we are past
          # authentication stage to signal possible authentication failures.
          @authenticating           = false
        end

        def upgrade_to_tls_if_necessary
          tls_options = @settings[:ssl]

          if tls_options.is_a?(Hash)
            start_tls(tls_options)
          elsif tls_options
            start_tls
          end
        end # upgrade_to_tls_if_necessary
      end # EventMachineClient
    end # Async
  end # Client
end # AMQ
