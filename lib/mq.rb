#:main: README
#

$:.unshift File.expand_path(File.dirname(File.expand_path(__FILE__)))
require 'amqp'

class MQ
  %w[ exchange queue rpc header ].each do |file|
    require "mq/#{file}"
  end

  class << self
    @logging = false
    attr_accessor :logging
  end

  # Raised whenever an illegal operation is attempted.
  class Error < StandardError; end
end

# The top-level class for building AMQP clients. This class contains several
# convenience methods for working with queues and exchanges. Many calls
# delegate/forwards to the appropriate subclass method.
class MQ
  include AMQP
  include EM::Deferrable

  # Returns a new channel. A channel is a bidirectional virtual
  # connection between the client and the AMQP server. Elsewhere in the
  # library the channel is referred to in parameter lists as 'mq'.
  #
  # Optionally takes the result from calling EventMachine::connect.
  #
  #  EM.run do
  #    channel = MQ.new
  #  end
  #
  #  EM.run do
  #    channel = MQ.new connect
  #  end
  #
  def initialize connection = nil
    raise 'MQ can only be used from within EM.run{}' unless EM.reactor_running?

    @connection = connection || AMQP.start

    conn.callback{ |c|
      @channel = c.add_channel(self)
      send Protocol::Channel::Open.new
    }
  end
  attr_reader :channel
  
  # May raise a MQ::Error exception when the frame payload contains a
  # Protocol::Channel::Close object. 
  #
  # This usually occurs when a client attempts to perform an illegal
  # operation. A short, and incomplete, list of potential illegal operations
  # follows:
  # * publish a message to a deleted exchange (NOT_FOUND)
  # * declare an exchange using the reserved 'amq.' naming structure (ACCESS_REFUSED)
  #
  def process_frame frame
    log :received, frame

    case frame
    when Frame::Header
      @header = frame.payload
      @body = ''

    when Frame::Body
      @body << frame.payload
      if @body.length >= @header.size
        @header.properties.update(@method.arguments)
        @consumer.receive @header, @body if @consumer
        @body = @header = @consumer = @method = nil
      end

    when Frame::Method
      case method = frame.payload
      when Protocol::Channel::OpenOk
        send Protocol::Access::Request.new(:realm => '/data',
                                           :read => true,
                                           :write => true,
                                           :active => true,
                                           :passive => true)

      when Protocol::Access::RequestOk
        @ticket = method.ticket
        callback{
          send Protocol::Channel::Close.new(:reply_code => 200,
                                            :reply_text => 'bye',
                                            :method_id => 0,
                                            :class_id => 0)
        } if @closing
        succeed

      when Protocol::Basic::CancelOk
        if @consumer = consumers[ method.consumer_tag ]
          @consumer.cancelled
        else
          MQ.error "Basic.CancelOk for invalid consumer tag: #{method.consumer_tag}"
        end

      when Protocol::Queue::DeclareOk
        queues[ method.queue ].recieve_status method

      when Protocol::Basic::Deliver, Protocol::Basic::GetOk
        @method = method
        @header = nil
        @body = ''

        if method.is_a? Protocol::Basic::GetOk
          @consumer = get_queue{|q| q.shift }
          MQ.error "No pending Basic.GetOk requests" unless @consumer
        else
          @consumer = consumers[ method.consumer_tag ]
          MQ.error "Basic.Deliver for invalid consumer tag: #{method.consumer_tag}" unless @consumer
        end

      when Protocol::Basic::GetEmpty
        @consumer = get_queue{|q| q.shift }
        @consumer.receive nil, nil

      when Protocol::Channel::Close
        raise Error, "#{method.reply_text} in #{Protocol.classes[method.class_id].methods[method.method_id]} on #{@channel}"

      when Protocol::Channel::CloseOk
        @closing = false
        conn.callback{ |c|
          c.channels.delete @channel
          c.close if c.channels.empty?
        }
      end
    end
  end

  def send *args
    conn.callback{ |c|
      (@_send_mutex ||= Mutex.new).synchronize do
        args.each do |data|
          data.ticket = @ticket if @ticket and data.respond_to? :ticket=
          log :sending, data
          c.send data, :channel => @channel
        end
      end
    }
  end

  # A convenience method for defining a direct exchange. See 
  # MQ::Exchange.new for details and available options.
  #
  #  direct_exch = MQ.direct('foo')
  #  # equivalent to
  #  direct_exch = MQ::Exchange.new(MQ.new, :direct, 'foo')
  #
  def direct name = 'amq.direct', opts = {}
    exchanges[name] ||= Exchange.new(self, :direct, name, opts)
  end

  # A convenience method for defining a fanout exchange. See 
  # MQ::Exchange.new for details and available options.
  #
  #  fanout_exch = MQ.fanout('foo')
  #  # equivalent to
  #  fanout_exch = MQ::Exchange.new(MQ.new, :fanout, 'foo')
  #
  def fanout name = 'amq.fanout', opts = {}
    exchanges[name] ||= Exchange.new(self, :fanout, name, opts)
  end

  # A convenience method for defining a topic exchange. See 
  # MQ::Exchange.new for details and available options.
  #
  #  topic_exch = MQ.topic('foo', :key => 'stocks.us')
  #  # equivalent to
  #  topic_exch = MQ::Exchange.new(MQ.new, :topic, 'foo', :key => 'stocks.us')
  #
  def topic name = 'amq.topic', opts = {}
    exchanges[name] ||= Exchange.new(self, :topic, name, opts)
  end
    
  # Convenience method for creating or retrieving a queue reference. Wraps
  # calls to MQ::Queue. See the MQ::Queue class definition for the 
  # allowable options.
  #
  #  queue = MQ.queue('bar', :durable => true)
  #
  # Equivalent to writing:
  #  channel = MQ.new
  #  queue = MQ::Queue.new(channel, 'bar', :durable => true)
  #
  def queue name, opts = {}
    queues[name] ||= Queue.new(self, name, opts)
  end

  # Convenience method for creating or retrieving an RPC (remote procedure
  # call) reference. Wraps calls to MQ::RPC. See the MQ::RPC class definition
  # for the allowable options.
  #
  #  remote_proc = MQ.rpc('bar', Hash.new)
  #
  # Equivalent to writing:
  #  channel = MQ.new
  #  remote_proc = MQ::RPC.new(channel, 'bar', Hash.new)
  #
  def rpc name, obj = nil
    rpcs[name] ||= RPC.new(self, name, obj)
  end

  def close
    if @deferred_status == :succeeded
      send Protocol::Channel::Close.new(:reply_code => 200,
                                        :reply_text => 'bye',
                                        :method_id => 0,
                                        :class_id => 0)
    else
      @closing = true
    end
  end

  # Define a message and callback block to be executed on all
  # errors.
  def self.error msg = nil, &blk
    if blk
      @error_callback = blk
    else
      @error_callback.call(msg) if @error_callback and msg
    end
  end

  # Returns a hash of all the exchange proxy objects.
  #
  # Not typically called by client code.
  def exchanges
    @exchanges ||= {}
  end

  # Returns a hash of all the queue proxy objects.
  #
  # Not typically called by client code.
  def queues
    @queues ||= {}
  end

  def get_queue
    if block_given?
      (@get_queue_mutex ||= Mutex.new).synchronize{
        yield( @get_queue ||= [] )
      }
    end
  end

  # Returns a hash of all rpc proxy objects.
  #
  # Not typically called by client code.
  def rpcs
    @rcps ||= {}
  end

  # Queue objects keyed on their consumer tags.
  def consumers
    @consumers ||= {}
  end

  def reset
    @deferred_status = nil
    @channel = nil
    initialize @connection

    @consumers = {}

    exs = @exchanges
    @exchanges = {}
    exs.each{ |_,e| e.reset } if exs

    qus = @queues
    @queues = {}
    qus.each{ |_,q| q.reset } if qus
  end

  private

  def log *args
    return unless MQ.logging
    pp args
    puts
  end

  attr_reader :connection
  alias :conn :connection
end

#-- convenience wrapper (read: HACK) for thread-local MQ object

class MQ
  def MQ.default
    #-- XXX clear this when connection is closed
    Thread.current[:mq] ||= MQ.new
  end

  def MQ.method_missing meth, *args, &blk
    MQ.default.__send__(meth, *args, &blk)
  end
end

class MQ
  # unique identifier
  def MQ.id
    Thread.current[:mq_id] ||= "#{`hostname`.strip}-#{Process.pid}-#{Thread.current.object_id}"
  end
end