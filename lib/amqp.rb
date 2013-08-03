# encoding: utf-8

require "amq/protocol"

require "amqp/version"
if RUBY_VERSION =~ /^1.8.7/
  require "amqp/compatibility/ruby187_patchlevel_check"
end

require "amqp/handlers_registry"
require "amqp/callbacks"
require "amqp/entity"

require "amqp/exceptions"
require "amqp/settings"
require "amqp/deferrable"
require "amqp/session"
require "amqp/exchange"
require "amqp/queue"
require "amqp/channel"
require "amqp/header"

# Top-level namespace of amqp gem. Please refer to "See also" section below.
#
# @see AMQP.connect
# @see AMQP.start
# @see AMQP::Channel
# @see AMQP::Exchange
# @see AMQP::Queue
module AMQP

  # Starts EventMachine event loop unless it is already running and connects
  # to AMQP broker using {AMQP.connect}. It is generally a good idea to
  # start EventMachine event loop in a separate thread and use {AMQP.connect}
  # (for Web applications that do not use Thin or Goliath, it is the only option).
  #
  # See {AMQP.connect} for information about arguments this method takes and
  # information about relevant topics such as authentication failure handling.
  #
  # @example Using AMQP.start to connect to AMQP broker, EventMachine loop isn't yet running
  #  AMQP.start do |connection|
  #    # default is to connect to localhost:5672, to root ("/") vhost as guest/guest
  #
  #    # this block never exits unless either AMQP.stop or EM.stop
  #    # is called.
  #
  #    AMQP::Channel(connection) do |channel|
  #      channel.queue("", :auto_delete => true).bind(channel.fanout("amq.fanout")).subscribe do |headers, payload|
  #        # handle deliveries here
  #      end
  #    end
  #  end
  #
  # @api public
  def self.start(connection_options_or_string = {}, other_options = {}, &block)
    EM.run do
      if !@connection || @connection.closed? || @connection.closing?
        @connection   = connect(connection_options_or_string, other_options, &block)
      end
      @channel      = Channel.new(@connection)
      @connection
    end
  end

  # Alias for {AMQP.start}
  # @api public
  def self.run(*args, &block)
    self.start(*args, &block)
  end

  # Properly closes default AMQP connection and then underlying TCP connection.
  # Pass it a block if you want a piece of code to be run once default connection
  # is successfully closed.
  #
  # @note If default connection was never established or is in the closing state already,
  #       this method has no effect.
  # @api public
  def self.stop(reply_code = 200, reply_text = "Goodbye", &block)
    return if @connection.nil? || self.closing?

    EM.next_tick do
      if AMQP.channel and AMQP.channel.open? and AMQP.channel.connection.open?
        AMQP.channel.close
      end
      AMQP.channel = nil


      shim = Proc.new {
        block.call

        AMQP.connection = nil
      }
      @connection.disconnect(reply_code, reply_text, &shim)
    end
  end

  # Indicates that default connection is closing.
  #
  # @return [Boolean]
  # @api public
  def self.closing?
    @connection.closing?
  end

  # @return [Boolean] Current global logging value
  # @api public
  def self.logging
    self.settings[:logging]
  end

  # @return [Boolean] Sets current global logging value
  # @api public
  def self.logging=(value)
    self.settings[:logging] = !!value
  end

  # Default connection. When you do not pass connection instance to methods like
  # {Channel#initialize}, AMQP gem will use this default connection.
  #
  # @api public
  def self.connection
    @connection
  end

  # "Default channel". A placeholder for apps that only want to use one channel. This channel is not global, *not* used
  # under the hood by methods like {AMQP::Exchange#initialize} and only shared by exchanges/queues you decide on.
  # To reiterate: this is only a conventience accessor, since many apps (especially Web apps) can get by with just one
  # connection and one channel.
  #
  # @api public
  def self.channel
    @channel
  end

  # A placeholder for applications that only need one channel. If you use {AMQP.start} to set up default connection,
  # {AMQP.channel} is open on that connection, but can be replaced by your application.
  #
  #
  # @see AMQP.channel
  # @api public
  def self.channel=(value)
    @channel = value
  end

  # Sets global connection object.
  # @api public
  def self.connection=(value)
    @connection = value
  end

  # Alias for {AMQP.connection}
  # @deprecated
  # @api public
  def self.conn
    warn "AMQP.conn will be removed in 1.0. Please use AMQP.connection."
    @connection
  end

  # Alias for {AMQP.connection=}
  # @deprecated
  # @api public
  def self.conn=(value)
    warn "AMQP.conn= will be removed in 1.0. Please use AMQP.connection=(connection)."
    self.connection = value
  end

  # Connects to AMQP broker and yields connection object to the block as soon
  # as connection is considered open.
  #
  #
  # @example Using AMQP.connect with default connection settings
  #
  #   AMQP.connect do |connection|
  #     AMQP::Channel.new(connection) do |channel|
  #       # channel is ready: set up your messaging flow by creating exchanges,
  #       # queues, binding them together and so on.
  #     end
  #   end
  #
  # @example Using AMQP.connect to connect to a public RabbitMQ instance with connection settings given as a hash
  #
  #   AMQP.connect(:host => "dev.rabbitmq.com", :username => "guest", :password => "guest") do |connection|
  #     AMQP::Channel.new(connection) do |channel|
  #       # ...
  #     end
  #   end
  #
  #
  # @example Using AMQP.connect to connect to a public RabbitMQ instance with connection settings given as a URI
  #
  #   AMQP.connect "amqp://guest:guest@dev.rabbitmq.com:5672", :on_possible_authentication_failure => Proc.new { puts("Looks like authentication has failed") } do |connection|
  #     AMQP::Channel.new(connection) do |channel|
  #       # ...
  #     end
  #   end
  #
  #
  # @overload connect(connection_string, options = {})
  #   Used to pass connection parameters as a connection string
  #   @param [String] :connection_string AMQP connection URI, à la JDBC connection string. For example: amqp://bus.megacorp.internal:5877/qa
  #
  #
  # @overload connect(connection_options)
  #   Used to pass connection options as a Hash.
  #   @param [Hash] :connection_options AMQP connection options (:host, :port, :username, :vhost, :password)
  #
  # @option connection_options_or_string [String]  :host ("localhost") Host to connect to.
  # @option connection_options_or_string [Integer] :port (5672) Port to connect to.
  # @option connection_options_or_string [String]  :vhost ("/") Virtual host to connect to.
  # @option connection_options_or_string [String]  :username ("guest") Username to use. Also can be specified as :user.
  # @option connection_options_or_string [String]  :password ("guest") Password to use. Also can be specified as :pass.
  # @option connection_options_or_string [Hash]  :ssl TLS (SSL) parameters to use.
  # @option connection_options_or_string [Fixnum] :heartbeat (0) Connection heartbeat, in seconds. 0 means no heartbeat. Can also be configured server-side starting with RabbitMQ 3.0.
  # @option connection_options_or_string [#call]  :on_tcp_connection_failure A callable object that will be run if connection to server fails
  # @option connection_options_or_string [#call]  :on_possible_authentication_failure A callable object that will be run if authentication fails (see Authentication failure section)
  #
  #
  # h2. Handling authentication failures
  #
  # AMQP 0.9.1 specification dictates that broker closes TCP connection when it detects that authentication
  # has failed. However, broker does exactly the same thing when other connection-level exception occurs
  # so there is no way to guarantee that connection was closed because of authentication failure.
  #
  # Because of that, AMQP gem follows Java client example and hints at _possibility_ of authentication failure.
  # To handle it, pass a callable object (a proc, a lambda, an instance of a class that responds to #call)
  # with :on_possible_authentication_failure option.
  #
  # @note This method assumes that EventMachine even loop is already running. If it is not the case or you are not sure, we recommend you use {AMQP.start} instead.
  #       It takes exactly the same parameters.
  # @return [AMQP::Session]
  # @api public
  def self.connect(connection_options_or_string = {}, other_options = {}, &block)
    opts = case connection_options_or_string
           when String then
             AMQP::Settings.parse_connection_uri(connection_options_or_string)
           when Hash then
             connection_options_or_string
           else
             Hash.new
           end

    AMQP::Session.connect(opts.merge(other_options), &block)
  end

  # @return [Hash] Default AMQP connection settings. This hash may be modified.
  # @api public
  def self.settings
    @settings ||= AMQP::Settings.default
  end
end # AMQP
