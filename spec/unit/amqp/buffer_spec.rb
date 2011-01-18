# encoding: utf-8

require "spec_helper"
require "amqp/buffer"


if [].map.respond_to? :with_index
  class Array #:nodoc:
    def enum_with_index
      each.with_index
    end
  end
else
  require 'enumerator'
end


describe AMQP::Buffer do

  #
  # Examples
  #

  it "has contents" do
    subject.contents.should == ""
  end

  it "can be initialized with data" do
    @buffer = described_class.new("abc")
    @buffer.contents.should == "abc"
  end

  it "can append strings" do
    subject << "abc"
    subject << "def"

    subject.contents.should == "abcdef"
  end

  it "can append other buffers" do
    subject << described_class.new("abc")

    subject.data.should == "abc"
  end

  it "has current position" do
    subject.pos.should == 0

    subject << described_class.new("abc")

    subject.pos.should == 0
  end


  it "has length" do
    subject.length.should == 0

    subject << "abc"

    subject.length.should == 3
    # check for a crazy case when both RSpec and Bacon are loaded;
    # then == matcher ALWAYS PASSES. Le sigh.
    subject.length.should_not == 300
  end


  it "provides emptiness predicate" do
    subject.should be_empty
    subject << "xyz"

    subject.should_not be_empty
  end


  it "supports writing of data" do
    subject._write("abc")
    subject.pos.should == 3
    subject.rewind
    subject.pos.should == 0
  end


  it "supports reading of data" do
    subject._write("abc")
    subject.rewind

    subject._read(2).should == "ab"
    subject.pos.should == 0
    subject._read(1).should == "c"
    subject.pos.should == 0
  end


  it "raises on overflow" do
    expect {
      subject._read(1)
    }.should raise_error(described_class::Overflow)
  end


  it "refuses reading of unsupported types" do
    expect {
      subject.read(:junk)
    }.to raise_error(described_class::InvalidType)
  end


  it "refuses writing of unsupported types" do
    expect {
      subject.write(:junk, 1)
    }.to raise_error(described_class::InvalidType)
  end


  { :octet => 0b10101010,
    :short => 100,
    :long => 100_000_000,
    :longlong => 666_555_444_333_222_111,
    :shortstr => 'hello',
    :longstr => 'bye'*500,
    :timestamp => time = Time.at(Time.now.to_i),
    :table => { :this => 'is', :a => 'hash', :with => {:nested => 123, :and => time, :also => 123.456} },
    :bit => true
  }.each do |type, value|
    it "can read and write a #{type}" do
      subject.write(type, value)
      subject.rewind

      subject.read(type).should == value
      subject.should be_empty
    end # it
  end # each


  it 'can read and write multiple bits' do
    bits = [true, false, false, true, true, false, false, true, true, false]
    subject.write(:bit, bits)
    subject.write(:octet, 100)

    subject.rewind

    bits.map do
      subject.read(:bit)
    end.should == bits
    subject.read(:octet).should == 100
  end

  it 'can read and write property tables' do
    properties = ([
                   [:octet, 1],
                   [:shortstr, 'abc'],
                   [:bit, true],
                   [:bit, false],
                   [:shortstr, nil],
                   [:timestamp, nil],
                   [:table, { :a => 'hash' }],
                  ]*5).sort_by {rand}

    subject.write(:properties, properties)
    subject.rewind
    subject.read(:properties, *properties.map { |type, _| type }).should == properties.map { |_, value| value }
    subject.should be_empty
  end

  it 'does transactional reads with #extract' do
    subject.write :octet, 8
    orig = subject.to_s

    subject.rewind
    subject.extract do |b|
      b.read :octet
      b.read :short
    end

    subject.pos.should == 0
    subject.data.should == orig
  end
end # describe
