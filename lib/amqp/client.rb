require 'amqp/frame'

module AMQP
  class Error < StandardError; end

  module BasicClient
    def process_frame frame
      if mq = channels[frame.channel]
        mq.process_frame(frame)
        return
      end
      
      case frame
      when Frame::Method
        case method = frame.payload
        when Protocol::Connection::Start
          send Protocol::Connection::StartOk.new({:platform => 'Ruby/EventMachine',
                                                  :product => 'AMQP',
                                                  :information => 'http://github.com/tmm1/amqp',
                                                  :version => VERSION},
                                                 'AMQPLAIN',
                                                 {:LOGIN => @settings[:user],
                                                  :PASSWORD => @settings[:pass]},
                                                 'en_US')

        when Protocol::Connection::Tune
          send Protocol::Connection::TuneOk.new(:channel_max => 0,
                                                :frame_max => 131072,
                                                :heartbeat => 0)

          send Protocol::Connection::Open.new(:virtual_host => @settings[:vhost],
                                              :capabilities => '',
                                              :insist => false)

        when Protocol::Connection::OpenOk
          succeed(self)

        when Protocol::Connection::Close
          raise Error, "#{method.reply_text} in #{Protocol.classes[method.class_id].methods[method.method_id]}"

        when Protocol::Connection::CloseOk
          @on_disconnect.call if @on_disconnect
        end
      end
    end
  end

  def self.client
    @client ||= BasicClient
  end
  
  def self.client= mod
    mod.__send__ :include, AMQP
    @client = mod
  end

  module Client
    include EM::Deferrable

    def initialize opts = {}
      @settings = opts
      extend AMQP.client

      @on_disconnect = proc{ raise Error, "Could not connect to server #{opts[:host]}:#{opts[:port]}" }

      timeout @settings[:timeout] if @settings[:timeout]
      errback{ @on_disconnect.call }
    end

    def connection_completed
      log 'connected'
      @on_disconnect = proc{ raise Error, 'Disconnected from server' }
      @buf = Buffer.new
      send_data HEADER
      send_data [1, 1, VERSION_MAJOR, VERSION_MINOR].pack('C4')
    end

    def unbind
      log 'disconnected'
      @on_disconnect.call unless $!
    end

    def add_channel mq
      (@_channel_mutex ||= Mutex.new).synchronize do
        channels[ key = (channels.keys.max || 0) + 1 ] = mq
        key
      end
    end

    def channels
      @channels ||= {}
    end
  
    def receive_data data
      # log 'receive_data', data
      @buf << data

      while frame = Frame.parse(@buf)
        log 'receive', frame
        process_frame frame
      end
    end

    def process_frame frame
      # this is a stub meant to be
      # replaced by the module passed into initialize
    end
  
    def send data, opts = {}
      channel = opts[:channel] ||= 0
      data = data.to_frame(channel) unless data.is_a? Frame
      data.channel = channel

      log 'send', data
      send_data data.to_s
    end

    # def send_data data
    #   log 'send_data', data
    #   super
    # end

    def close &on_disconnect
      @on_disconnect = on_disconnect if on_disconnect

      callback{ |c|
        if c.channels.any?
          c.channels.each do |ch, mq|
            mq.close
          end
        else
          send Protocol::Connection::Close.new(:reply_code => 200,
                                               :reply_text => 'Goodbye',
                                               :class_id => 0,
                                               :method_id => 0)
        end
      }
    end
  
    def self.connect opts = {}
      opts = AMQP.settings.merge(opts)
      EM.connect opts[:host], opts[:port], self, opts
    end
  
    private
  
    def log *args
      return unless @settings[:logging] or AMQP.logging
      require 'pp'
      pp args
      puts
    end
  end
end