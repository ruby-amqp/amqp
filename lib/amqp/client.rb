require 'eventmachine'
require 'amqp/frame'
require 'pp'

module AMQP
  module Client
    def initialize blk
      @blk = blk
    end

    def connection_completed
      log 'connected'
      @buf = Buffer.new
      send_data HEADER
      send_data [1, 1, VERSION_MAJOR, VERSION_MINOR].pack('CCCC')
    end
  
    def receive_data data
      @buf << data
      log 'receive_data', data

      while frame = Frame.parse(@buf)
        log 'receive', frame
        
        case method = frame.payload
        when Protocol::Connection::Start
          send Protocol::Connection::StartOk.new({:platform => 'Ruby/EventMachine',
                                                  :product => 'AMQP',
                                                  :information => 'http://github.com/tmm1/amqp',
                                                  :version => '0.1.0'},
                                                 'AMQPLAIN',
                                                 {:LOGIN => 'guest',
                                                  :PASSWORD => 'guest'},
                                                 'en_US')

        when Protocol::Connection::Tune
          send Protocol::Connection::TuneOk.new :channel_max => 0,
                                                :frame_max => 131072,
                                                :heartbeat => 0

          send Protocol::Connection::Open.new :virtual_host => '/',
                                              :capabilities => '',
                                              :insist => false

        when Protocol::Connection::OpenOk
          send Protocol::Channel::Open.new, :channel => 1
        
        when Protocol::Channel::OpenOk
          send Protocol::Access::Request.new(:realm => '/data',
                                             :read => true,
                                             :write => true,
                                             :active => true), :channel => 1

        when Protocol::Access::RequestOk
          @ticket = method.ticket
          send Protocol::Queue::Declare.new(:ticket => @ticket,
                                            :queue => '',
                                            :exclusive => false,
                                            :auto_delete => true), :channel => 1

        when Protocol::Queue::DeclareOk
          @queue = method.queue
          send Protocol::Queue::Bind.new(:ticket => @ticket,
                                         :queue => @queue,
                                         :exchange => '',
                                         :routing_key => 'test_route'), :channel => 1

        when Protocol::Queue::BindOk
          send Protocol::Basic::Consume.new(:ticket => @ticket,
                                            :queue => @queue,
                                            :no_local => false,
                                            :no_ack => true), :channel => 1

        when Protocol::Basic::ConsumeOk
          data = "this is a test!"

          send Protocol::Basic::Publish.new(:ticket => @ticket,
                                            :exchange => '',
                                            :routing_key => 'test_route'), :channel => 1
          send Protocol::Header.new(Protocol::Basic, data.length, :content_type => 'application/octet-stream',
                                                                  :delivery_mode => 1,
                                                                  :priority => 0), :channel => 1
          send Frame::Body.new(data), :channel => 1
        end
      end
    end
  
    def send data, opts = {}
      channel = opts[:channel] ||= 0
      data = data.to_frame(channel) unless data.is_a? Frame
      data.channel = channel
      log 'send', data
      send_data data.to_s
    end

    def send_data data
      log 'send_data', data
      super
    end

    def unbind
      log 'disconnected'
    end
  
    def self.connect host = 'localhost', port = PORT, &blk
      EM.run{
        EM.connect host, port, self, blk
      }
    end
  
    private
  
    def log *args
      pp args
      puts
    end
  end

  def self.start *args, &blk
    Client.connect *args, &blk
  end
end

if $0 == __FILE__
  AMQP.start do |amqp|
    # ...
  end
end