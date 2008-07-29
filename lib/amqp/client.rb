require 'amqp/frame'

module AMQP
  class Error < Exception; end

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
          @dfr.succeed(self)

        when Protocol::Connection::Close
          raise Error, "#{method.reply_text} in #{Protocol.classes[method.class_id].methods[method.method_id]}"

        when Protocol::Connection::CloseOk
          AMQP.stopped
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
    def initialize dfr, opts = {}
      @dfr = dfr
      @settings = opts
      extend AMQP.client
    end

    def connection_completed
      log 'connected'
      @buf = Buffer.new
      send_data HEADER
      send_data [1, 1, VERSION_MAJOR, VERSION_MINOR].pack('C4')
    end

    def add_channel mq
      channels[ key = (channels.keys.max || 0) + 1 ] = mq
      key
    end

    def channels mq = nil
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

    def close
      send Protocol::Connection::Close.new(:reply_code => 200,
                                           :reply_text => 'Goodbye',
                                           :class_id => 0,
                                           :method_id => 0)
    end

    def unbind
      log 'disconnected'
    end
  
    def self.connect opts = {}
      opts = AMQP.settings.merge(opts)
      opts[:host] ||= 'localhost'
      opts[:port] ||= PORT

      dfr = EM::DefaultDeferrable.new
      
      EM.run{
        EM.connect opts[:host], opts[:port], self, dfr, opts
      }
      
      dfr
    end
  
    private
  
    def log *args
      return unless AMQP.logging
      require 'pp'
      pp args
      puts
    end
  end
end