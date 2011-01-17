# encoding: utf-8

require 'spec_helper'

describe MQ, ' basic specs' do
  include AMQP::Spec

  default_timeout 5

  amqp_before do
    @mq = MQ.new
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
    done
  end

  it 'should return amq.direct if no name given' do
    @mq.direct.name.should == 'amq.direct'
    done
  end

  it 'should generate a new name if the name was nil' do
    pending <<-EOF
      This has to be fixed in RabbitMQ first
      https://bugzilla.rabbitmq.com/show_bug.cgi?id=23509
    EOF
    @mq.direct("") do |exchange|
      exchange.name.should_not be_empty
      done
    end
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
