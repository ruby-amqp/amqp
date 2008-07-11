require 'rubygems'
require 'eventmachine'

require 'amqp_spec'

module AMQP
  HEADER = 'AMQP'.freeze

  class BufferOverflow < Exception; end
  class InvalidFrame < Exception; end

  module Protocol
    class Class::Method
      def initialize *args
        opts = args.pop if args.size == 1 and args.last.is_a? Hash
        
        if args.size == 1 and args.first.is_a? Buffer
          buf = args.first
        else
          buf = nil
        end

        self.class.arguments.each do |type, name|
          if buf
            val = buf.parse(type)
          else
            val = args.shift || opts[name] || opts[name.to_s]
          end

          instance_variable_set("@#{name}", val) if val
        end
      end

      def to_binary
        [ self.class.parent.id, id ].pack('nn') +
          self.class.arguments.inject('') do |str, (type, name)|
            str + pack(type, instance_variable_get("@#{name}"))
          end
      end
      alias :to_s :to_binary
      
      def to_frame channel = 0
        Frame.new(:method, channel, self)
      end
      
      private
      
      def pack type, data
        return '' unless data

        case type
          when :octet
            [data].pack('C')
          when :short
            [data].pack('n')
          when :long
            [data].pack('N')
          when :shortstr
            len = data.length
            [len, data].pack("Ca#{len}")
          when :longstr
            if data.is_a? Hash
              data = pack(:table, data)
            end

            len = data.length
            [len, data].pack("Na#{len}")
          when :table
            data.inject('') do |str, (key, value)|
              str + pack(:shortstr, key) + pack(:octet, ?S) + pack(:longstr, value.to_s)
            end
          when :longlong
          when :bit
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

      if @type == :method and payload.is_a? String
        @payload = Protocol.parse(payload)
      else
        @payload = payload
      end
    end
    attr_reader :type, :channel, :payload

    def to_binary
      data = payload.to_s
      size = data.length
      [TYPES.index(type), channel, size, data, FRAME_END].pack("CnNa#{size}C")
    end
    alias :to_s :to_binary

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
      AMQP::Frame.new(2, 0, 'abc').to_binary.should == "\002\000\000\000\000\000\003abc\316"
    end

    should 'return type as symbol' do
      AMQP::Frame.new(3, 0, 'abc').type.should == :body
      AMQP::Frame.new(:body, 0, 'abc').type.should == :body
    end
  end
  
  describe AMQP::Buffer do
    @frame = AMQP::Frame.new(2, 0, 'abc')
    
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

  describe AMQP::Protocol do
    @method = AMQP::Protocol::Connection::StartOk.new({:platform => 'Ruby/EventMachine',
                                                       :product => 'AMQP',
                                                       :information => 'http://github.com/tmm1/amqp',
                                                       :version => '0.0.1'},
                                                      'PLAIN',
                                                      {:LOGIN => 'guest',
                                                       :PASSWORD => 'guest'},
                                                      'en_US')
                                                      
    should 'generate method packets' do
      meth = AMQP::Protocol::Connection::StartOk.new :locale => 'en_US',
                                                     :mechanism => 'PLAIN'
      meth.locale.should == @method.locale
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