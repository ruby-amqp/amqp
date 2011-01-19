# encoding: utf-8

require "spec_helper"
require "amqp/protocol"

describe AMQP::Protocol do
  it 'should instantiate methods with arguments' do
    meth = AMQP::Protocol::Connection::StartOk.new nil, 'PLAIN', nil, 'en_US'
    meth.locale.should == 'en_US'
  end

  it 'should instantiate methods with named parameters' do
    meth = AMQP::Protocol::Connection::StartOk.new :locale => 'en_US',
                                             :mechanism => 'PLAIN'
    meth.locale.should == 'en_US'
  end

  it 'should convert methods to binary' do
    meth = AMQP::Protocol::Connection::Secure.new :challenge => 'secret'
    meth.to_binary.should be_kind_of AMQP::Buffer

    meth.to_s.should == [10, 20, 6, 'secret'].pack('nnNa*')
  end

  it 'should convert binary to method' do
    orig = AMQP::Protocol::Connection::Secure.new :challenge => 'secret'
    copy = AMQP::Protocol.parse orig.to_binary
    orig.should == copy
  end

  it 'should convert headers to binary' do
    head = AMQP::Protocol::Header.new AMQP::Protocol::Basic,
                                size = 5,
                                weight = 0,
                                :content_type => 'text/json',
                                :delivery_mode => 1,
                                :priority => 1
    head.to_s.should ==
        [60, weight, 0, size, 0b1001_1000_0000_0000, 9, 'text/json', 1, 1].pack('nnNNnCa*CC')
  end

  it 'should convert binary to header' do
    orig = AMQP::Protocol::Header.new AMQP::Protocol::Basic,
                                size = 5,
                                weight = 0,
                                :content_type => 'text/json',
                                :delivery_mode => 1,
                                :priority => 1
    AMQP::Protocol::Header.new(orig.to_binary).should == orig
  end
end
