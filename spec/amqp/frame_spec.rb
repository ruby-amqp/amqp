# encoding: utf-8

require 'spec_helper'

describe AMQP::Frame do
  include AMQP

  it 'should handle basic frame types' do
    Frame::Method.new.id.should == 1
    Frame::Header.new.id.should == 2
    Frame::Body.new.id.should == 3
  end

  it 'should convert method frames to binary' do
    meth = Protocol::Connection::Secure.new :challenge => 'secret'

    frame = Frame::Method.new(meth)
    frame.to_binary.should be_kind_of Buffer
    frame.to_s.should == [1, 0, meth.to_s.length, meth.to_s, 206].pack('CnNa*C')
  end

  it 'should convert binary to method frames' do
    orig = Frame::Method.new Protocol::Connection::Secure.new(:challenge => 'secret')

    copy = Frame.parse(orig.to_binary)
    copy.should == orig
  end

  it 'should ignore partial frames until ready' do
    frame = Frame::Method.new Protocol::Connection::Secure.new(:challenge => 'secret')
    data = frame.to_s

    buf = Buffer.new
    Frame.parse(buf).should == nil

    buf << data[0..5]
    Frame.parse(buf).should == nil

    buf << data[6..-1]
    Frame.parse(buf).should == frame

    Frame.parse(buf).should == nil
  end

  it 'should convert header frames to binary' do
    head = Protocol::Header.new(Protocol::Basic, :priority => 1)

    frame = Frame::Header.new(head)
    frame.to_s.should == [2, 0, head.to_s.length, head.to_s, 206].pack('CnNa*C')
  end

  it 'should convert binary to header frame' do
    orig = Frame::Header.new Protocol::Header.new(Protocol::Basic, :priority => 1)

    copy = Frame.parse(orig.to_binary)
    copy.should == orig
  end
end
