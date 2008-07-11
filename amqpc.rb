require 'rubygems'
require 'eventmachine'

class String
  def ord() self[0] end
end unless "abc".respond_to? :ord # for ruby 1.9 compat

require 'amqp_spec'

module AMQP
  HEADER = 'AMQP'.freeze

  class BufferOverflow < Exception; end
  class InvalidFrame < Exception; end

  module Protocol
    class Class::Method
      def initialize buf
        self.class.arguments.each do |type, name|
          instance_variable_set("@#{name}", buf.parse(type))
        end
      end
    end

    def self.parse payload
      buf = Buffer.new(payload)
      class_id, method_id = buf.parse(:short, :short)
      classes[class_id].methods[method_id].new(buf)
    end
  end

  class Frame
    TYPES = [ nil, :method, :header, :body, :'oob-method', :'oob-header', :'oob-body', :trace, :heartbeat ]

    def initialize type, channel, payload
      @channel = channel
      @type = (1..8).include?(type) ? TYPES[type] :
                                      TYPES.include?(type) ? type : raise(InvalidFrame)
      @payload = case @type
                 when :method
                   Protocol.parse(payload)
                 else
                   payload
                 end
    end
    attr_reader :type, :channel, :payload

    def to_binary
      size = payload.length
      [TYPES.index(type), channel, size, payload, FRAME_END].pack("CnNa#{size}C")
    end

    def == b
      type == b.type and
      channel == b.channel and
      payload == b.payload
    end
  end

  class Buffer
    def initialize data = ''
      @data = data
      @pos = 0
    end
    attr_reader :pos
    
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
          raise InvalidFrame
        end
        processed = @pos
      end
    rescue BufferOverflow
      # log 'buffer overflow', @pos, processed
      @data[0..processed] = '' if processed > 0
      @pos = 0
      frames
    end

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
            t = Hash.new

            table = Buffer.new(parse(:longstr))
            until table.eof?
              key, type = table.parse(:shortstr, :octet)
              t[key] = case type
                         when ?S
                           table.parse(:longstr)
                         when ?I
                           table.parse(:long)
                         when ?D
                           d = table.parse(:octet)
                           table.parse(:long) / (10**d)
                         when ?T
                           table.parse(:timestamp)
                         when ?F
                           table.parse(:table)
                       end
            end

            t
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

    def eof?
      @pos == @data.length
    end

    private

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
      # log 'receive', data
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
      pp args
    end
  end
end

require 'pp'

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
["got a frame",
 #<AMQP::Frame:0x1190c48
  @channel=0,
  @payload=
   #<AMQP::Protocol::Connection::Start:0x119093c
    @locales="en_US",
    @mechanisms="PLAIN AMQPLAIN",
    @server_properties=
     {"platform"=>"Erlang/OTP",
      "product"=>"RabbitMQ",
      "information"=>"Licensed under the MPL.  See http://www.rabbitmq.com/",
      "version"=>"%%VERSION%%",
      "copyright"=>
       "Copyright (C) 2007-2008 LShift Ltd., Cohesive Financial Technologies LLC., and Rabbit Technologies Ltd."},
    @version_major=8,
    @version_minor=0>,
  @type=:method>]