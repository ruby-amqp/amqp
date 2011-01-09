# encoding: utf-8

require 'spec_helper'

describe MQ do
  include AMQP::Spec

  default_timeout 5

  amqp_before do
    @mq = MQ.new
  end

  it 'should have a channel' do
    @mq.channel.should be_kind_of Fixnum
    @mq.channel.should == 1
    done
  end

  it 'should give each thread a message queue' do
    pending 'This is not implemented in current lib'
    class MQ
      @@cur_channel = 0
    end
    MQ.channel.should == 1
    Thread.new { MQ.channel }.value.should == 2
    Thread.new { MQ.channel }.value.should == 3
    done
  end

  it 'should create direct exchanges' do
    @mq.direct('name').name.should == 'name'
    @mq.direct.name.should == 'amq.direct'
    @mq.direct(nil).name.should =~ /^\d+$/
    done
  end

  it 'should create fanout and topic exchanges' do
    @mq.fanout.name.should == 'amq.fanout'
    @mq.topic.name.should == 'amq.topic'
    done
  end

  it 'should create queues' do
    q = @mq.queue('test')
    done
  end
end
