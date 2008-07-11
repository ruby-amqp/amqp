require 'rubygems'
require 'eventmachine'

class String
  def ord() self[0] end
end unless "abc".respond_to? :ord

require 'amqp_spec'

module AMQP
  HEADER = 'AMQP'.freeze

  class Frame < Struct.new(:type, :channel, :payload)
    TYPES = [ nil, :method, :header, :body, :'oob-method', :'oob-header', :'oob-body', :trace, :heartbeat ]

    def type
      @type ||= TYPES.include?(self[:type]) ? self[:type] : TYPES[ self[:type] ]
    end

    def to_binary
      size = payload.length
      [TYPES.index(type), channel, size, payload, FRAME_END].pack("CnNa#{size}C")
    end
  end

  class BufferOverflow < Exception; end

  class Buffer
    def initialize data = ''
      @data = data
      @pos = 0
    end
    
    def extract data = nil
      @data << data if data
      
      processed = 0
      frames = []

      while true
        type, channel, size = parse(:octet, :short, :long)
        payload = read(size)
        if read(1) == FRAME_END.chr
          frames << Frame.new(type, channel, payload)
        else
          log 'invalid frame'
        end
        processed = @pos
      end
    rescue BufferOverflow
      # log 'buffer overflow', @pos, processed
      @data[0..processed] = '' if processed > 0
      @pos = 0
      frames
    end

    private
    
    def parse *syms
      res = syms.map do |sym|
        # log 'parsing', sym
        case sym
          when :octet
            read(1, 'C')
          when :short
            read(2, 'n')
          when :long
            read(4, 'N')
          when :longlong
            # FIXME
          when :shortstr
            len = parse(:octet)
            read(len)
          when :longstr
            len = parse(:long)
            read(len)
          when :timestamp
            parse(:longlong)
          when :bit
            # FIXME
          when :table
            
            # t = _read_table
            # if res.is_a?(Array)
            #   res << t
            # else
            #   res = t
            # end
          else
            # FIXME remove
        end
      end

      syms.length == 1 ? res[0] : res
    end

    def read len, type = nil
      # log 'reading', len, type, :pos => @pos
      raise BufferOverflow if @pos+len > @data.length

      d = @data.slice(@pos, len)
      @pos += len
      d = d.unpack(type).pop if type
      # log 'read', d
      d
    end

    def log *args
      p args
    end
  end

  module Connection
    def connection_completed
      log 'connected'
      @buffer = Buffer.new
      send_data HEADER
      send_data [1, 1, VERSION_MAJOR, VERSION_MINOR].pack('CCCC')
    end
  
    def receive_data data
      log 'receive', data
      @buffer.extract(data).each do |frame|
        log 'got a frame', frame
      end
    end
  
    def send_data data
      # log 'send', data
      super
    end

    def unbind
      log 'disconnected'
    end
  
    def self.start host = 'localhost', port = 5672
      EM.run{
        EM.connect host, port, self
      }
    end
  
    private
  
    def log *args
      p args
    end
  end
end

if $0 == __FILE__
  EM.run{
    AMQP::Connection.start
  }
elsif $0 =~ /bacon/
  describe AMQP::Frame do
    should 'convert to binary' do
      AMQP::Frame.new(1, 0, 'abc').to_binary.should == "\001\000\000\000\000\000\003abc\316"
    end

    should 'return type as symbol' do
      AMQP::Frame.new(1, 0, 'abc').type.should == :method
      AMQP::Frame.new(:method, 0, 'abc').type.should == :method
    end
  end
  
  describe AMQP::Buffer do
    @frame = AMQP::Frame.new(1, 0, 'abc')
    
    should 'parse complete frames' do
      frame = AMQP::Buffer.new(@frame.to_binary).extract.first

      frame.should.be.kind_of? AMQP::Frame
      frame.payload.should.be == @frame.payload
      frame.should.be == @frame
    end

    should 'not return incomplete frames until complete' do
      buffer = AMQP::Buffer.new(@frame.to_binary[0..5])
      buffer.extract.should == []
      buffer.extract(@frame.to_binary[6..-1]).should == [@frame]
      buffer.extract.should == []
    end
  end
end

__END__

["connected"]
["got a frame", #<struct AMQP::Frame type=1, channel=0, size=294, payload="\000\n\000\n\b\000\000\000\001\001\aproductS\000\000\000\bRabbitMQ\aversionS\000\000\000\v%%VERSION%%\bplatformS\000\000\000\nErlang/OTP\tcopyrightS\000\000\000gCopyright (C) 2007-2008 LShift Ltd., Cohesive Financial Technologies LLC., and Rabbit Technologies Ltd.\vinformationS\000\000\0005Licensed under the MPL.  See http://www.rabbitmq.com/\000\000\000\016PLAIN AMQPLAIN\000\000\000\005en_US">]