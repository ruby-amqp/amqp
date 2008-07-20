$:.unshift File.expand_path(File.dirname(File.expand_path(__FILE__)))
require 'amqp'

unless defined?(BlankSlate)
  class BlankSlate < BasicObject; end if defined?(BasicObject)

  class BlankSlate
    instance_methods.each { |m| undef_method m unless m =~ /^__/ }
  end
end

class MQ
  include AMQP
  include EM::Deferrable

  class Exchange
    include AMQP

    def initialize mq, type, name, opts = {}
      @mq = mq
      @type, @name = type, name
      @key = opts[:key]

      @mq.callback{
        @mq.send Protocol::Exchange::Declare.new({ :exchange => name,
                                                   :type => type,
                                                   :nowait => true }.merge(opts))
      } unless name == "amq.#{type}" or name == ''
    end
    attr_reader :name, :type, :key

    def publish data, opts = {}
      @mq.callback{
        EM.next_tick do
          @mq.send Protocol::Basic::Publish.new({ :exchange => name,
                                                  :routing_key => opts.delete(:key) || @key }.merge(opts))
        
          data = data.to_s

          @mq.send Protocol::Header.new(Protocol::Basic,
                                            data.length, { :content_type => 'application/octet-stream',
                                                           :delivery_mode => 1,
                                                           :priority => 0 }.merge(opts))
          @mq.send Frame::Body.new(data)
        end
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

    def publish data, opts = {}
      exchange.publish(data, opts)
    end

    def receive headers, body
      if @on_msg
        @on_msg.call *(@on_msg.arity == 1 ? [body] : [headers, body])
      end
    end
  
    private
    
    def exchange
      @exchange ||= Exchange.new(@mq, :direct, '', :key => name)
    end
  end

  class RPC < BlankSlate
    def initialize mq, queue, obj = nil
      @mq = mq

      if obj
        @obj = case obj
               when Class
                 obj.new
               when Module
                 (::Class.new do include(obj) end).new
               else
                 obj
               end
        
        @mq.queue(queue).subscribe{ |info, request|
          method, *args = Marshal.load(request)
          ret = @obj.__send__(method, *args)

          if info.reply_to
            @mq.queue(info.reply_to).publish(Marshal.dump(ret), :key => info.reply_to, :message_id => info.message_id)
          end
        }
      else
        @callbacks ||= {}
        @queue = @mq.queue(@name = 'some random identifier for me').subscribe{|info, msg|
          if blk = @callbacks.delete(info.message_id)
            blk.call Marshal.load(msg)
          end
        }
        @remote = @mq.queue(queue)
      end
    end

    def method_missing meth, *args, &blk
      message_id = "random message id #{rand(999_999_999_999)}"
      @callbacks[message_id] = blk if blk
      @remote.publish(Marshal.dump([meth, *args]), :reply_to => blk ? @name : nil, :message_id => message_id)
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
  
  def exchanges
    @exchanges ||= {}
  end

  def queues
    @queues ||= {}
  end

  def rpcs
    @rcps ||= {}
  end

  def connection
    @@connection ||= AMQP.start
  end
  alias :conn :connection

  def log *args
    return unless MQ.logging
    pp args
    puts
  end

  def MQ.method_missing meth, *args, &blk
    MQ.default.__send__(meth, *args, &blk)
  end
  
  def MQ.default
    Thread.current[:mq] ||= MQ.new
  end

  def MQ.logging
    @logging ||= false
  end
  
  def MQ.logging= logging
    @logging = logging
  end
end