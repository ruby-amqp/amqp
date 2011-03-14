# encoding: utf-8

require "amqp/ext/em"
require "amqp/ext/blankslate"

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
      @conn ||= connect(*args, &block)
      @conn
    end
  end

  # @api public
  def self.run(*args, &block)
    start(*args, &block)
  end

  # @api public
  def self.stop
    # TODO
  end

  # @api public
  def self.logging
    # TODO
  end

  # @api public
  def self.logging=(value)
    # TODO
  end


  # @api public
  def self.connection
    # TODO
  end

  # @api public
  def self.connection=(value)
    # TODO
  end

  # @api public
  def self.conn
    # TODO
  end

  # @api public
  def self.conn=(value)
    # TODO
  end

  # @api public
  def self.connect(*args, &block)
    Client.connect(*args, &block)
  end

  # @api public
  def self.settings
    # TODO
  end

  # @api public
  def self.fork(workers)
    # TODO
  end
end # AMQP
