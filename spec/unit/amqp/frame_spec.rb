# encoding: utf-8


require "spec_helper"
require "amqp/frame"

describe AMQP::Frame do
  include AMQP

  it 'should handle basic frame types' do
    AMQP::Frame::Method.new.id.should == 1
    AMQP::Frame::Header.new.id.should == 2
    AMQP::Frame::Body.new.id.should == 3
  end

  it 'should convert method frames to binary' do
    meth = AMQP::Protocol::Connection::Secure.new :challenge => 'secret'

    frame = AMQP::Frame::Method.new(meth)
    frame.to_binary.should be_kind_of(AMQP::Buffer)
    frame.to_s.should == [1, 0, meth.to_s.length, meth.to_s, 206].pack('CnNa*C')
  end

  it 'should convert binary to method frames' do
    orig = AMQP::Frame::Method.new(AMQP::Protocol::Connection::Secure.new(:challenge => 'secret'))

    copy = AMQP::Frame.parse(orig.to_binary)
    copy.should == orig
  end

  it 'should ignore partial frames until ready' do
    frame = AMQP::Frame::Method.new(AMQP::Protocol::Connection::Secure.new(:challenge => 'secret'))
    data = frame.to_s

    buf = AMQP::Buffer.new
    AMQP::Frame.parse(buf).should == nil

    buf << data[0..5]
    AMQP::Frame.parse(buf).should == nil

    buf << data[6..-1]
    AMQP::Frame.parse(buf).should == frame

    AMQP::Frame.parse(buf).should == nil
  end

  it 'should convert header frames to binary' do
    head = AMQP::Protocol::Header.new(AMQP::Protocol::Basic, :priority => 1)

    frame = AMQP::Frame::Header.new(head)
    frame.to_s.should == [2, 0, head.to_s.length, head.to_s, 206].pack('CnNa*C')
  end

  it 'should convert binary to header frame' do
    orig = AMQP::Frame::Header.new(AMQP::Protocol::Header.new(AMQP::Protocol::Basic, :priority => 1))

    copy = AMQP::Frame.parse(orig.to_binary)
    copy.should == orig
  end
end
