$:.unshift File.expand_path(File.dirname(File.expand_path(__FILE__)))
require 'amqp'

class MQ
  include AMQP
  include EM::Deferrable

  class Exchange
    include AMQP

    def initialize mq, type, name, opts = {}
      if name.is_a? Hash
        opts = name
        name = "amq.#{type}"
      end

      @mq = mq
      @type, @name = type, name
      @key = opts[:key]

      @mq.callback{
        @mq.send Protocol::Exchange::Declare.new({ :exchange => name,
                                                   :type => type,
                                                   :nowait => true }.merge(opts))
      } unless name == "amq.#{type}"
    end
    attr_reader :name, :type, :key

    def publish data, opts = {}
      @mq.callback{
        @mq.send Protocol::Basic::Publish.new({ :exchange => name,
                                                :routing_key => opts.delete(:key) || @key }.merge(opts))
        
        data = data.to_s

        @mq.send Protocol::Header.new(Protocol::Basic,
                                          data.length, { :content_type => 'application/octet-stream',
                                                         :delivery_mode => 1,
                                                         :priority => 0 }.merge(opts))
        @mq.send Frame::Body.new(data)
      }
      self
    end
  end
  
  class Queue
    include AMQP
    
    def initialize mq, name, opts = {}
      @mq = mq
      @name = name
      @mq.callback{
        @mq.send Protocol::Queue::Declare.new({ :queue => name,
                                                :nowait => true }.merge(opts))
      }
      bind(@mq.direct, :key => name)
    end
    attr_reader :name

    def bind exchange, opts = {}
      @mq.callback{
        @mq.send Protocol::Queue::Bind.new({ :queue => name,
                                             :exchange => exchange.respond_to?(:name) ? exchange.name : exchange,
                                             :routing_key => opts.delete(:key),
                                             :nowait => true }.merge(opts))
      }
      self
    end
    
    def subscribe opts = {}, &blk
      @on_msg = blk
      @mq.callback{
        @mq.send Protocol::Basic::Consume.new({ :queue => name,
                                                :consumer_tag => name,
                                                :no_ack => true,
                                                :nowait => true }.merge(opts))
      }
      self
    end
    
    def receive headers, body
      if @on_msg
        @on_msg.call *(@on_msg.arity == 1 ? [body] : [headers, body])
      end
    end
  end
end

class MQ
  def initialize
    conn.callback{ |c|
      @channel = c.add_channel(self)
      send Protocol::Channel::Open.new
    }
  end
  attr_reader :channel
  
  def process_frame frame
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

  private
  
  def exchanges
    @exchanges ||= {}
  end

  def queues
    @queues ||= {}
  end

  def connection
    @@connection ||= AMQP.start
  end
  alias :conn :connection

  def MQ.method_missing meth, *args, &blk
    MQ.default.__send__(meth, *args, &blk)
  end
  
  def MQ.default
    Thread.current[:mq] ||= MQ.new
  end
end