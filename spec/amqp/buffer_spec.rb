require 'spec_helper'
require 'amqp/buffer'

describe AMQP::Buffer do
  include AMQP
  before { @buf = Buffer.new }
  subject { @buf }

  its(:contents) { should == '' }

  it 'should initialize with data' do
    Buffer.new('abc').contents.should == 'abc'
  end

  it 'should append raw data' do
    @buf << 'abc'
    @buf << 'def'
    @buf.contents.should == 'abcdef'
  end

  it 'should append other buffers' do
    @buf << Buffer.new('abc')
    @buf.data.should == 'abc'
  end

  it 'should have a position' do
    @buf.pos.should == 0
  end

  it 'should have a length' do
    @buf.length.should == 0
    @buf << 'abc'
    @buf.length.should == 3
  end

  it 'should know the end' do
    @buf.empty?.should == true
  end

  it 'should read and write data' do
    @buf._write('abc')
    @buf.rewind
    @buf._read(2).should == 'ab'
    @buf._read(1).should == 'c'
  end

  it 'should raise on overflow' do
    expect { @buf._read(1) }.to raise_error Buffer::Overflow
  end

  it 'should raise on invalid types' do
    expect { @buf.read(:junk) }.to raise_error Buffer::InvalidType
    expect { @buf.write(:junk, 1) }.to raise_error Buffer::InvalidType
  end

  {:octet => 0b10101010,
   :short => 100,
   :long => 100_000_000,
   :longlong => 666_555_444_333_222_111,
   :shortstr => 'hello',
   :longstr => 'bye'*500,
   :timestamp => time = Time.at(Time.now.to_i),
   :table => {:this => 'is', :a => 'hash', :with => {:nested => 123, :and => time, :also => 123.456}},
   :bit => true
  }.each do |type, value|

    it "should read and write a #{type}" do
      @buf.write(type, value)
      @buf.rewind
      @buf.read(type).should == value
      @buf.should be_empty
    end

  end

  it 'should read and write multiple bits' do
    bits = [true, false, false, true, true, false, false, true, true, false]
    @buf.write(:bit, bits)
    @buf.write(:octet, 100)

    @buf.rewind

    bits.map{@buf.read(:bit)}.should == bits
    @buf.read(:octet).should == 100
    @buf.should be_empty
  end

  it 'should read and write properties' do
    properties = ([
        [:octet, 1],
        [:shortstr, 'abc'],
        [:bit, true],
        [:bit, false],
        [:shortstr, nil],
        [:timestamp, nil],
        [:table, {:a => 'hash'}],
    ]*5).sort_by { rand }

    @buf.write(:properties, properties)
    @buf.rewind
    @buf.read(:properties, *properties.map { |type, _| type }).should == properties.map { |_, value| value }
    @buf.should be_empty
  end

  it 'should do transactional reads with #extract' do
    @buf.write :octet, 8
    orig = @buf.to_s

    @buf.rewind
    @buf.extract do |b|
      b.read :octet
      b.read :short
    end

    @buf.pos.should == 0
    @buf.data.should == orig
  end
end
