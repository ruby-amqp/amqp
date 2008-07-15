require 'amqp_spec'
require 'buffer'
require 'method'

module AMQP
  class Frame
    def initialize payload = nil, channel = 0
      @channel, @payload = channel, payload
    end
    attr_accessor :channel, :payload

    def id
      self.class::ID
    end
    
    def to_binary
      buf = Buffer.new
      buf.write :octet, id
      buf.write :short, channel
      buf.write :longstr, payload
      buf.write :octet, FOOTER
      buf.rewind
      buf
    end

    def to_s
      to_binary.to_s
    end

    def == frame
      [ :id, :channel, :payload ].inject(true) do |eql, field|
        eql and __send__(field) == frame.__send__(field)
      end
    end

    def self.types
      @types ||= {}
    end
    
    def self.Frame id
      (@_base_frames ||= {})[id] ||= Class.new(Frame) do
        class_eval %[
          def self.inherited klass
            klass.const_set(:ID, #{id})
            Frame.types[#{id}] = klass
          end
        ]
      end
    end
    
    class Invalid < Exception; end
    
    class Method < Frame(1)
      def initialize payload = nil, channel = 0
        super
        unless @payload.is_a? Protocol::Class::Method
          @payload = Protocol.parse(@payload) if @payload
        end
      end
    end         
                
    class Header < Frame(2)
    end         
                
    class Body   < Frame(3)
    end

    def self.parse buf
      buf = Buffer.new(buf) unless buf.is_a? Buffer
      id, channel, payload, footer = buf.read(:octet, :short, :longstr, :octet)
      Frame.types[id].new(payload, channel)
    end
  end
end

if $0 =~ /bacon/ or $0 == __FILE__
  require 'bacon'
  include AMQP

  describe Frame do
    should 'handle basic frame types' do
      Frame::Method.new.id.should == 1
      Frame::Header.new.id.should == 2
      Frame::Body.new.id.should == 3
    end

    should 'convert method frames to binary' do
      meth = Protocol::Connection::Secure.new :challenge => 'secret'

      frame = Frame::Method.new(meth)
      frame.to_binary.should.be.kind_of? Buffer
      frame.to_s.should == [ 1, 0, meth.to_s.length, meth.to_s, 206 ].pack('CnNa*C')
    end

    should 'convert binary to method frames' do
      orig = Frame::Method.new(Protocol::Connection::Secure.new :challenge => 'secret')

      copy = Frame.parse(orig.to_binary)
      copy.should == orig
      
      copy.payload.should == orig.payload
    end
  end
end