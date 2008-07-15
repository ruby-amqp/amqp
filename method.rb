require 'amqp_spec'
require 'buffer'

module AMQP
  module Protocol
    class Class::Method
      def initialize *args
        opts = args.pop if args.last.is_a? Hash
        opts ||= {}
        
        @debug = 1 # XXX hack, p(obj) == '' if no instance vars are set
        
        if args.size == 1 and args.first.is_a? Buffer
          buf = args.shift
        else
          buf = nil
        end

        self.class.arguments.each do |type, name|
          val = buf ? buf.read(type) :
                      args.shift || opts[name] || opts[name.to_s]
          instance_variable_set("@#{name}", val)
        end
      end

      def to_binary
        buf = Buffer.new
        buf.write :short, self.class.parent.id
        buf.write :short, self.class.id

        bits = []

        self.class.arguments.each do |type, name|
          val = instance_variable_get("@#{name}")
          if type == :bit
            bits << val
          else
            if bits.any?
              buf.write :bit, bits
              bits = []
            end
            buf.write type, val
          end
        end

        buf.write :bit, bits if bits.any?
        buf.rewind

        buf
      end
      
      def to_s
        to_binary.to_s
      end
      
      def to_frame channel = 0
        Frame::Method(self, channel)
      end
    end

    class Header
      def initialize klass, size = 0, args = {}
        @klass, @size, @args = klass, size, args
      end
      attr_accessor :klass, :size, :args
      
      def to_binary
        buf = Buffer.new
        buf.write :short, klass.id
        buf.write :short, weight = 0 # XXX rabbitmq only supports weight == 0
        buf.write :longlong, size
        buf.write :properties, (klass.properties.map do |type, name|
                                 [ type, args[name] || args[name.to_s] ]
                               end)
        buf.rewind
        buf
      end
      
      def to_s
        to_binary.to_s
      end
    end

    def self.parse buf
      buf = Buffer.new(buf) unless buf.is_a? Buffer
      class_id, method_id = buf.read(:short, :short)
      classes[class_id].methods[method_id].new(buf)
    end
  end
end

if $0 =~ /bacon/ or $0 == __FILE__
  require 'bacon'
  include AMQP

  describe Protocol do
    should 'instantiate methods with arguments' do
      meth = Protocol::Connection::StartOk.new nil, 'PLAIN', nil, 'en_US'
      meth.locale.should == 'en_US'
    end

    should 'instantiate methods with named parameters' do
      meth = Protocol::Connection::StartOk.new :locale => 'en_US',
                                               :mechanism => 'PLAIN'
      meth.locale.should == 'en_US'
    end

    should 'convert methods to binary' do
      meth = Protocol::Connection::Secure.new :challenge => 'secret'
      meth.to_binary.should.be.kind_of? Buffer

      meth.to_s.should == [ 10, 20, 6, 'secret' ].pack('nnNa*')
    end

    should 'convert binary to method' do
      orig = Protocol::Connection::Secure.new :challenge => 'secret'
      copy = Protocol.parse orig.to_binary
      orig.should == copy
    end

    should 'convert headers to binary' do
      head = Protocol::Header.new Protocol::Basic,
                                  5,
                                  :content_type => 'text/json',
                                  :delivery_mode => 1,
                                  :priority => 1
      head.to_s.should == [ 60, 0, 0, 5, 0b1001_1000_0000_0000, 9, 'text/json', 1, 1 ].pack('nnNNnCa*CC')
    end
  end
end