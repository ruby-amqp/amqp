require 'spec_helper'
require 'mq_helper'

describe 'MQ', 'class object' do
#  after{AMQP.cleanup_state} # Tips off Thread.current[:mq] call
  subject { MQ }

  its(:logging) { should be_false }


  describe '.logging=' do
    it 'is independent from AMQP.logging' do
      #
      AMQP.logging = true
      MQ.logging.should be_false
      MQ.logging = false
      AMQP.logging.should == true

      #
      AMQP.logging = false
      MQ.logging = true
      AMQP.logging.should be_false
      MQ.logging = false
    end
  end # .logging=


  describe '.default' do
    it 'creates MQ object and stashes it in a Thread-local Hash' do
      MQ.should_receive(:new).with(no_args).and_return('MQ mock')
      Thread.current.should_receive(:[]).with(:mq)
      Thread.current.should_receive(:[]=).with(:mq, 'MQ mock')
      MQ.default.should == 'MQ mock'
    end
  end # .default



  describe '.id' do
    it 'returns Thread-local uuid for mq' do
      uuid_pattern = /.*-[0-9]*-[0-9]*/
      Thread.current.should_receive(:[]).with(:mq_id)
      Thread.current.should_receive(:[]=).with(:mq_id, uuid_pattern)
      MQ.id.should =~ uuid_pattern
    end
  end # .id



  describe '.error' do
    after(:all) { MQ.instance_variable_set(:@error_callback, nil) } # clear error callback

    it 'is noop unless @error_callback was previously set' do
      MQ.instance_variable_get(:@error_callback).should be_nil
      MQ.error("Msg").should be_nil
    end

    context 'when @error_callback is set' do
      before { MQ.error { |message| message.should == "Msg"; @callback_fired = true } }

      it 'is setting @error_callback to given block' do
        MQ.instance_variable_get(:@error_callback).should_not be_nil
        @callback_fired.should be_false
      end

      it 'does not fire @error_callback immediately' do
        @callback_fired.should be_false
      end

      it 'fires @error_callback on subsequent .error calls' do
        MQ.error("Msg")
        @callback_fired.should be_true
      end
    end
  end # .error



  describe '.method_missing' do
    it 'routes all unrecognized methods to MQ.default' do
      MQ.should_receive(:new).with(no_args).and_return(mock('channel'))
      MQ.default.should_receive(:foo).with("Msg")
      MQ.foo("Msg")
    end
  end # .method_missing
end # describe 'MQ as a class'




describe 'Channel object' do
  context 'when initialized with a mock connection' do
    before { @client = MockConnection.new }
    after { AMQP.cleanup_state }
    subject { MQ.new(@client).tap { |mq| mq.succeed } } # Indicates that channel is connected

    it 'should have a channel' do
      subject.channel.should be_kind_of Fixnum
      subject.channel.should == 1 # Essentially, this channel (mq) number
    end

    it 'has publicly accessible collections' do
      subject.exchanges.should be_empty
      subject.queues.should be_empty
      subject.consumers.should be_empty
      subject.rpcs.should be_empty
    end

    describe '#send' do
      it 'sends given data through its connection' do
        args = [ 'data1', 'data2', 'data3']
        subject.send *args
        @client.messages[-3..-1].map { |message| message[:data] }.should == args
      end #send

      it 'sets data`s ticket property if @ticket is set for MQ object' do
        ticket = subject_mock(:@ticket)
        data = mock('data')
        data.should_receive(:ticket=).with(ticket)
        subject.send data
      end
    end



    describe '#reset' do
      it 'resets and reinitializes the channel, clears and resets its queues/exchanges' do
        subject.queue('test').should_receive(:reset)
        subject.fanout('fanout').should_receive(:reset)
        subject.should_receive(:initialize).with(@client)

        subject.reset
        subject.queues.should be_empty
        subject.exchanges.should be_empty
        subject.consumers.should be_empty
      end
    end #reset



    describe '#prefetch', 'setting :prefetch_count for broker' do
      it 'sends Protocol::Basic::Qos' do
        subject.prefetch 13
        @client.messages.last[:data].should be_an AMQP::Protocol::Basic::Qos
        @client.messages.last[:data].instance_variable_get(:@prefetch_count).should == 13
      end

      it 'returns MQ object itself, allowing for method chains' do
        subject.prefetch(1).should == subject
      end
    end #prefetch



    describe '#recover', "asks broker to redeliver unack'ed messages on this channel" do
      it "sends Basic::Recover through @connection" do
        subject.recover
        @client.messages.last[:data].should be_an AMQP::Protocol::Basic::Recover
      end

      it 'defaults to :requeue=nil, redeliver messages to the original recipient' do
        subject.recover
        @client.messages.last[:data].instance_variable_get(:@requeue).should == nil
      end #prefetch

      it 'prompts broker to requeue messages (to other subs) if :requeue set to true' do
        subject.recover true
        @client.messages.last[:data].instance_variable_get(:@requeue).should == true
      end

      it 'returns MQ object itself, allowing for method chains' do
        subject.recover.should == subject
      end
    end #recover



    describe '#close', 'closes channel' do
      it 'can be simplified, getting rid of @closing ivar?'
      # TODO: Just set a callback sending Protocol::Channel::Close...'

      it 'sends Channel::Close through @connection' do
        subject.close
        @client.messages.last[:data].should be_an AMQP::Protocol::Channel::Close
      end

      it 'does not actually delete the channel or close connection' do
        @client.channels.should_not_receive(:delete)
        @client.should_not_receive(:close)
        subject.close
      end

      it 'actual channel closing happens ONLY when Channel::CloseOk is received' do
        @client.channels.should_receive(:delete) do |key|
          key.should == 1
          @client.channels.clear
        end
        @client.should_receive(:close)
        subject.process_frame AMQP::Frame::Method.new(AMQP::Protocol::Channel::CloseOk.new)
      end
    end #close




    describe '#get_queue', 'supports #pop (Basic::Get) operation on queues' do
      it 'yields a FIFO queue to a given block' do
        subject.get_queue do |fifo|
          @block_called = true
          fifo.should == []
        end
        @block_called.should be_true
      end

      it 'FIFO queue contains consumers that called Queue#pop' do
        queue1 = subject.queue('test1')
        queue2 = subject.queue('test2')
        queue1.pop
        queue2.pop
        subject.get_queue do |fifo|
          fifo.should have(2).consumers
          fifo.first.should == queue1
          fifo.last.should == queue2
        end
      end
    end #get_queue
  end #  context 'when initialized with a mock connection'
end # describe MQ object, also vaguely known as "channel"
