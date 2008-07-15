require 'amqp_spec'
require 'buffer'

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
      buf
    end
    alias :to_s :to_binary
    
    def self.Frame id
      (@_base_frames ||= {})[id] ||= Class.new(Frame) do
        class_eval %[
          def self.inherited klass
            klass.const_set(:ID, #{id})
          end
        ]
      end
    end
    
    class Method < Frame(1)
    end         
                
    class Header < Frame(2)
    end         
                
    class Body   < Frame(3)
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

    should 'convert to binary' do
      binary = Frame::Method.new('abc').to_binary
      binary.should.be.kind_of? Buffer
      binary.to_s.should == [ 1, 0, 3, 'abc', 206 ].pack('CnNa*C')
    end
  end
end