$:.unshift File.expand_path(File.dirname(File.expand_path(__FILE__)))
require 'amqp'

class MQ
  %w[ exchange queue rpc ].each do |file|
    require "mq/#{file}"
  end

  class << self
    @logging = false
    attr_accessor :logging
  end
end

class MQ
  include AMQP
  include EM::Deferrable

  def initialize
    conn.callback{ |c|
      @channel = c.add_channel(self)
      send Protocol::Channel::Open.new
    }
  end
  attr_reader :channel
  
  def process_frame frame
    log :received, frame

    case frame
    when Frame::Header
      @header = frame.payload
      @body = ''

    when Frame::Body
      @body << frame.payload
      if @body.length >= @header.size
        @consumer.receive @header, @body
        @body = ''
      end

    when Frame::Method
      case method = frame.payload
      when Protocol::Channel::OpenOk
        send Protocol::Access::Request.new(:realm => '/data',
                                           :read => true,
                                           :write => true,
                                           :active => true)

      when Protocol::Access::RequestOk
        @ticket = method.ticket
        succeed

      when Protocol::Basic::Deliver
        @header = nil
        @body = ''
        @consumer = queues[ method.consumer_tag ]
      end
    end
  end

  def send data
    data.ticket = @ticket if @ticket and data.respond_to? :ticket
    conn.callback{ |c|
      log :sending, data
      c.send data, :channel => @channel
    }
  end

  %w[ direct topic fanout ].each do |type|
    class_eval %[
      def #{type} name = 'amq.#{type}', opts = {}
        exchanges[name] ||= Exchange.new(self, :#{type}, name, opts)
      end
    ]
  end

  def queue name, opts = {}
    queues[name] ||= Queue.new(self, name, opts)
  end

  def rpc name, obj = nil
    rpcs[name] ||= RPC.new(self, name, obj)
  end

  private
  
  def log *args
    return unless MQ.logging
    pp args
    puts
  end

  # keep track of proxy objects
  
  def exchanges
    @exchanges ||= {}
  end

  def queues
    @queues ||= {}
  end

  def rpcs
    @rcps ||= {}
  end

  # create a class level connection on demand

  def connection
    @@connection ||= AMQP.start
  end
  alias :conn :connection
end

# convenience wrapper for thread-local MQ object

class MQ
  def MQ.default
    Thread.current[:mq] ||= MQ.new
  end

  def MQ.method_missing meth, *args, &blk
    MQ.default.__send__(meth, *args, &blk)
  end
end

# unique identifier
class MQ
  def MQ.id
    Thread.current[:mq_id] ||= "#{`hostname`.strip}-#{Process.pid}-#{Thread.current.object_id}"
  end
end