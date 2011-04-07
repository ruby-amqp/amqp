# encoding: utf-8

require "amqp/ext/em"

require "amqp/client"

module AMQP

  # Must be called to startup the connection to the AMQP server.
  #
  # The method takes several arguments and an optional block.
  #
  # This takes any option that is also accepted by EventMachine::connect.
  # Additionally, there are several AMQP-specific options.
  #
  # * :user => String (default 'guest')
  # The username as defined by the AMQP server.
  # * :pass => String (default 'guest')
  # The password for the associated :user as defined by the AMQP server.
  # * :vhost => String (default '/')
  # The virtual host as defined by the AMQP server.
  # * :timeout => Numeric (default nil)
  # Measured in seconds.
  # * :logging => true | false (default false)
  # Toggle the extremely verbose logging of all protocol communications
  # between the client and the server. Extremely useful for debugging.
  #
  #  AMQP.start do
  #    # default is to connect to localhost:5672
  #
  #    # define queues, exchanges and bindings here.
  #    # also define all subscriptions and/or publishers
  #    # here.
  #
  #    # this block never exits unless EM.stop_event_loop
  #    # is called.
  #  end
  #
  # Most code will use the MQ api. Any calls to AMQP::Channel.direct / AMQP::Channel.fanout /
  # AMQP::Channel.topic / AMQP::Channel.queue will implicitly call #start. In those cases,
  # it is sufficient to put your code inside of an EventMachine.run
  # block. See the code examples in AMQP for details.
  #
  # @api public
  def self.start(*args, &block)
    EM.run do
      @connection ||= connect(*args, &block)
      @connection
    end
  end

  # @api public
  def self.run(*args, &block)
    self.start(*args, &block)
  end

  # @api public
  def self.stop(reply_code = 200, reply_text = "Goodbye", &block)
    return if self.closing?

    EM.next_tick do
      @connection.disconnect(reply_code, reply_text, &block)
    end
  end

  def self.closing?
    @connection.closing?
  end


  # @api public
  def self.logging
    @logging ||= false
  end

  # @api public
  def self.logging=(value)
    @logging = !! value
  end


  # @api public
  def self.connection
    @connection
  end

  # @api public
  def self.connection=(value)
    @connection = value
  end

  # @api public
  def self.conn
    warn "This method will be removed in 1.0. Please use AMQP.connection."
    @connection
  end

  # @api public
  def self.conn=(value)
    warn "This method will be removed in 1.0. Please use AMQP.connection=(connection)."
    self.connection = value
  end

  # @api public
  def self.connect(*args, &block)
    Client.connect(*args, &block)
  end

  # @api public
  def self.settings
    @settings ||= {
      :host    => "127.0.0.1",
      :port    => 5672,
      :user    => "guest",
      :pass    => "guest",
      :vhost   => "/",
      :timeout => nil,
      :logging => false,
      :ssl     => false
    }
  end

  # @api public
  def self.fork(workers)
    # TODO
    raise NotImplementedError.new
  end
end # AMQP
