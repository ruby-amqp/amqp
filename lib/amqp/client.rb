require 'rubygems'
require 'eventmachine'
require 'amqp/frame'
require 'pp'

module AMQP
  def self.client
    @client ||= BasicClient
  end
  
  def self.client= mod
    mod.__send__ :include, AMQP
    @client = mod
  end

  module Client
    def initialize dfr
      @dfr = dfr
      extend AMQP.client
    end

    def connection_completed
      log 'connected'
      @buf = Buffer.new
      send_data HEADER
      send_data [1, 1, VERSION_MAJOR, VERSION_MINOR].pack('C4')
    end
  
    def receive_data data
      @buf << data
      log 'receive_data', data

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

    def send_data data
      log 'send_data', data
      super
    end

    def unbind
      log 'disconnected'
    end
  
    def self.connect opts = {}
      opts[:host] ||= 'localhost'
      opts[:port] ||= PORT

      dfr = EM::DefaultDeferrable.new
      
      EM.run{
        EM.connect opts[:host], opts[:port], self, dfr
      }
      
      dfr
    end
  
    private
  
    def log *args
      return unless AMQP.logging
      pp args
      puts
    end
  end

  def self.start *args
    @conn ||= Client.connect *args
  end
end

if $0 == __FILE__
  AMQP.start
end