require 'spec_helper'
require 'mq_helper'

describe MQ::Queue, :broker => true do

  #
  # Environment
  #

  include AMQP::Spec

  default_options AMQP_OPTS
  default_timeout 3

  amqp_before do
    @channel = MQ.new
    @queue   = MQ::Queue.new(@channel, 'test_queue', :option => 'useless')
  end

  amqp_after { @queue.purge; AMQP.cleanup_state }


  #
  # Examples
  #

  context 'declared with name of "test_queue"' do
    amqp_after {@queue.unsubscribe; @queue.delete}
    # TODO: Fix amqp_after: it is NOT run in case of raised exceptions, it seems

    it 'supports asynchronous subscription to broker-predefined amq.direct exchange' do
      data = "data sent via amq.direct exchange"

      @queue.subscribe do |header, message|
        header.should be_an MQ::Header
        message.should == data
        done
      end
      @queue.publish(data)
    end # it

    it 'supports synchronous message fetching via #pop (Basic.Get)' do
      @queue.publish('send some data down the pipe')

      @queue.pop do |header, message|
        header.should be_an MQ::Header
        message.should == 'send some data down the pipe'
        done
      end
    end # it

    xit 'asynchronously receives own status from the broker' do
      pending "TODO: this example currently fails; do investigate why. MK."
      total_number_of_messages = 123

      total_number_of_messages.times do |n|
        @queue.publish('message # #{n}')
      end

      @on_status_fired = false
      @queue.status do |messages, consumers|
        @on_status_fired = true
        messages.should == total_number_of_messages
        consumers.should == 0
      end # it

      @on_status_fired.should be_true
      done(1)
    end # it
  end # context
end # MQ::Queue, 'with real connection
