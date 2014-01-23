# encoding: utf-8

require "eventmachine"
require "amqp/framing/string/frame"
require "amqp/auth_mechanism_adapter"
require "amqp/broker"

require "amqp/channel"
require "amqp/channel_id_allocator"

module AMQP
  # AMQP session represents connection to the broker. Session objects let you define callbacks for
  # various TCP connection lifecycle events, for instance:
  #
  # * Connection is established
  # * Connection has failed
  # * Authentication has failed
  # * Connection is lost (there is a network failure)
  # * AMQP connection is opened
  # * AMQP connection parameters (tuning) are negotiated and accepted by the broker
  # * AMQP connection is properly closed
  #
  # h2. Key methods
  #
  # * {Session#on_connection}
  # * {Session#on_open}
  # * {Session#on_disconnection}
  # * {Session#on_possible_authentication_failure}
  # * {Session#on_tcp_connection_failure}
  # * {Session#on_tcp_connection_loss}
  # * {Session#reconnect}
  # * {Session#connected?}
  #
  #
  # @api public
  class Session < EM::Connection
  include AMQP::ChannelIdAllocator

    #
    # Behaviours
    #

    include Openable
    include Callbacks

    extend ProtocolMethodHandlers
    extend RegisterEntityMixin


    register_entity :channel, AMQP::Channel

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


    class << self
      # Settings
      def settings
        @settings ||= AMQP::Settings.default
      end

      def logger
        @logger ||= begin
                      require "logger"
                      Logger.new(STDERR)
                    end
      end

      def logger=(logger)
        methods = AMQP::Logging::REQUIRED_METHODS
        unless methods.all? { |method| logger.respond_to?(method) }
          raise AMQP::Logging::IncompatibleLoggerError.new(methods)
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

    end


    # @group Connecting, reconnecting, disconnecting

    def initialize(*args, &block)
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

      @on_tcp_connection_failure          = Proc.new { |settings|
        closed!
        if cb = @settings[:on_tcp_connection_failure]
          cb.call(settings)
        else
          raise self.class.tcp_connection_failure_exception_class.new(settings)
        end
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
    end # initialize(*args, &block)

    # @return [Boolean] true if this AMQP connection is currently open
    # @api plugin
    def connected?
      self.opened?
    end

    # @return [String] Broker hostname this connection uses
    # @api public
    def hostname
      @settings[:host]
    end
    alias host hostname

    # @return [String] Broker port this connection uses
    # @api public
    def port
      @settings[:port]
    end

    # @return [String] Broker endpoint in the form of HOST:PORT/VHOST
    # @api public
    def broker_endpoint
      "#{self.hostname}:#{self.port}/#{self.vhost}"
    end

    # @return [String] Username used by this connection
    # @api public
    def username
      @settings[:user]
    end # username
    alias user username


    # Properly close connection with AMQ broker, as described in
    # section 2.2.4 of the {http://files.travis-ci.org/docs/amqp/0.9.1/AMQP091Specification.pdf AMQP 0.9.1 specification}.
    #
    # @api  plugin
    # @see  #close_connection
    def disconnect(reply_code = 200, reply_text = "Goodbye", &block)
      @intentionally_closing_connection = true
      self.on_disconnection do
        @frames.clear
        block.call if block
      end

      # ruby-amqp/amqp#66, MK.
      if self.open?
        closing!
        self.send_frame(AMQ::Protocol::Connection::Close.encode(reply_code, reply_text, 0, 0))
      elsif self.closing?
        # no-op
      else
        self.disconnection_successful
      end
    end
    alias close disconnect

    # @endgroup



    # @group Broker information

    # Server properties (product information, platform, et cetera)
    #
    # @return [Hash]
    # @see http://files.travis-ci.org/docs/amqp/0.9.1/AMQP091Reference.pdf AMQP 0.9.1 protocol documentation (Section 1.4.2.1.3)
    attr_reader :server_properties

    # Server capabilities (usually used to detect AMQP 0.9.1 extensions like basic.nack, publisher
    # confirms and so on)
    #
    # @return [Hash]
    # @see http://files.travis-ci.org/docs/amqp/0.9.1/AMQP091Reference.pdf AMQP 0.9.1 protocol documentation (Section 1.4.2.1.3)
    attr_reader :server_capabilities

    # Locales server supports
    #
    # @see http://files.travis-ci.org/docs/amqp/0.9.1/AMQP091Reference.pdf AMQP 0.9.1 protocol documentation (Section 1.4.2.1.3)
    attr_reader :server_locales

    # @return [AMQP::Broker] Broker this connection is established with
    def broker
      @broker ||= AMQP::Broker.new(@server_properties)
    end # broker

    # @endgroup



    # Defines a callback that will be executed when AMQP connection is considered open:
    # after client and broker has agreed on max channel identifier and maximum allowed frame
    # size and authentication succeeds. You can define more than one callback.
    #
    # @see #on_closed
    # @api public
    def on_open(&block)
      @connection_deferrable.callback(&block)
    end
    alias on_connection on_open


    # @group Error Handling and Recovery

    # Defines a callback that will be run when broker confirms connection termination
    # (client receives connection.close-ok). You can define more than one callback.
    #
    # @see #on_closed
    # @api public
    def on_closed(&block)
      @disconnection_deferrable.callback(&block)
    end
    alias on_disconnection on_closed

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

    # Defines a callback that will be executed after TCP connection is interrupted (typically because of a network failure).
    # Only one callback can be defined (the one defined last replaces previously added ones).
    #
    # @api public
    def on_connection_interruption(&block)
      self.redefine_callback(:after_connection_interruption, &block)
    end
    alias after_connection_interruption on_connection_interruption


    # Defines a callback that will be executed when connection is closed after
    # connection-level exception. Only one callback can be defined (the one defined last
    # replaces previously added ones).
    #
    # @api public
    def on_error(&block)
      self.redefine_callback(:error, &block)
    end


    # Defines a callback that will be executed after TCP connection has recovered after a network failure
    # but before AMQP connection is re-opened.
    # Only one callback can be defined (the one defined last replaces previously added ones).
    #
    # @api public
    def before_recovery(&block)
      self.redefine_callback(:before_recovery, &block)
    end


    # Defines a callback that will be executed after AMQP connection has recovered after a network failure..
    # Only one callback can be defined (the one defined last replaces previously added ones).
    #
    # @api public
    def on_recovery(&block)
      self.redefine_callback(:after_recovery, &block)
    end
    alias after_recovery on_recovery


    # @return [Boolean] whether connection is in the automatic recovery mode
    # @api public
    def auto_recovering?
      !!@auto_recovery
    end
    alias auto_recovery? auto_recovering?


    # Performs recovery of channels that are in the automatic recovery mode.
    #
    # @see Channel#auto_recover
    # @see Queue#auto_recover
    # @see Exchange#auto_recover
    # @api plugin
    def auto_recover
      @channels.select { |channel_id, ch| ch.auto_recovering? }.each { |n, ch| ch.auto_recover }
    end # auto_recover

    # @endgroup



    #
    # Implementation
    #

    # Overrides TCP connection failure exception to one that inherits from AMQP::Error
    # and thus is backwards compatible.
    #
    # @private
    # @api plugin
    # @return [Class] AMQP::TCPConnectionFailed
    def self.tcp_connection_failure_exception_class
      @tcp_connection_failure_exception_class ||= AMQP::TCPConnectionFailed
    end # self.tcp_connection_failure_exception_class


    # Overrides authentication failure exception to one that inherits from AMQP::Error
    # and thus is backwards compatible.
    #
    # @private
    # @api plugin
    # @return [Class] AMQP::PossibleAuthenticationFailureError
    def self.authentication_failure_exception_class
      @authentication_failure_exception_class ||= AMQP::PossibleAuthenticationFailureError
    end # self.authentication_failure_exception_class

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
    def reconnect_to(connection_string_or_options, period = 5)
      settings = case connection_string_or_options
                 when String then
                   AMQP.parse_connection_uri(connection_string_or_options)
                 when Hash then
                   connection_string_or_options
                 else
                   Hash.new
                 end

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
        self.receive_frame(AMQP::Framing::String::Frame.decode(frame))
      end
    end


    # Called by AMQP::Connection after we receive connection.open-ok.
    # @api public
    def connection_successful
      @authenticating = false
      opened!

      @connection_deferrable.succeed
    end # connection_successful


    # Called by AMQP::Connection after we receive connection.close-ok.
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

    # @private
    # @api plugin
    def handle_connection_interruption
      self.cancel_heartbeat_sender

      @channels.each { |n, c| c.handle_connection_interruption }
      self.exec_callback_yielding_self(:after_connection_interruption)
    end



    # @private
    def run_before_recovery_callbacks
      self.exec_callback_yielding_self(:before_recovery, @settings)

      @channels.each { |n, ch| ch.run_before_recovery_callbacks }
    end


    # @private
    def run_after_recovery_callbacks
      self.exec_callback_yielding_self(:after_recovery, @settings)

      @channels.each { |n, ch| ch.run_after_recovery_callbacks }
    end


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
      self.send_frame(AMQ::Protocol::Connection::Open.encode(vhost))
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
        if callable = AMQP::HandlersRegistry.find(frame.method_class)
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
        send_frame(AMQ::Protocol::HeartbeatFrame)
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

      self.send_frame(AMQ::Protocol::Connection::StartOk.encode(@client_properties, mechanism, self.encode_credentials(username, password), @locale))
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

      self.send_frame(AMQ::Protocol::Connection::TuneOk.encode(@channel_max, [settings[:frame_max], @frame_max].min, @heartbeat_interval))
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
      # getting connection.close during connection negotiation means authentication
      # has failed (RabbitMQ 3.2+):
      # http://www.rabbitmq.com/auth-notification.html
      if authenticating?
        @on_possible_authentication_failure.call(@settings) if @on_possible_authentication_failure
      end
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



    self.handle(AMQ::Protocol::Connection::Start) do |connection, frame|
      connection.handle_start(frame.decode_payload)
    end

    self.handle(AMQ::Protocol::Connection::Tune) do |connection, frame|
      connection.handle_tune(frame.decode_payload)

      connection.open(connection.vhost)
    end

    self.handle(AMQ::Protocol::Connection::OpenOk) do |connection, frame|
      connection.handle_open_ok(frame.decode_payload)
    end

    self.handle(AMQ::Protocol::Connection::Close) do |connection, frame|
      connection.handle_close(frame.decode_payload)
    end

    self.handle(AMQ::Protocol::Connection::CloseOk) do |connection, frame|
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
  end # Session
end # AMQP
