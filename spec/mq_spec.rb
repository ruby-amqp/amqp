require 'spec_helper'
require 'mq_helper'

describe 'MQ', 'as a class' do
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

describe 'MQ', 'object, also known as "channel"' do

  context 'when initialized with a mock connection' do
    before { @client = MockConnection.new }
    after { AMQP.cleanup_state }
    subject { MQ.new(@client).tap { |mq| mq.succeed } } # Indicates that channel is connected

    it 'has public accessors' do
      subject.channel.should == 1 # Essentially, this channel (mq) number
      subject.consumers.should be_empty
      subject.exchanges.should be_empty
      subject.queues.should be_empty
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

      it 'is Mutex-synchronized' do
        mutex = subject.instance_variable_get(:@_send_mutex)
        mutex.should_receive(:synchronize)
        subject.send mock('data1')
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

      it 'is Mutex-synchronized' do
        subject # Evaluates subject, tripping add_channel Mutex at initialize
        mutex = Mutex.new
        Mutex.should_receive(:new).and_return(mutex)
        mutex.should_receive(:synchronize)
        subject.get_queue {}
      end
    end #get_queue

    describe 'setting up exchanges/queues/rpcs' do
      describe '#rpc' do
        it 'creates new rpc and saves it into @rpcs Hash' do
          MQ::RPC.should_receive(:new).with(subject, 'name', nil).and_return('mock_rpc')
          subject.rpcs.should_receive(:[]=).with('name', 'mock_rpc')
          rpc = subject.rpc 'name'
          rpc.should == 'mock_rpc'
        end

        it 'raises error rpc if no name given' do
          expect { subject.rpc }.to raise_error ArgumentError
        end

        it 'does not replace rpc with existing name' do
          MQ::RPC.should_receive(:new).with(subject, 'name', nil).and_return('mock_rpc')
          subject.rpc 'name'
          MQ::RPC.should_not_receive(:new)
          subject.rpcs.should_not_receive(:[]=)
          rpc = subject.rpc 'name'
          rpc.should == 'mock_rpc'
        end
      end #rps

      describe '#queue' do
        it 'creates new Queue and adds it into @queues collection' do
          mock_queue = mock('mock_queue', :name => 'name')
          MQ::Queue.should_receive(:new).with(subject, 'name', {}).and_return(mock_queue)
          queue = subject.queue 'name'
          queue.should == mock_queue
          subject.queues['name'].should == mock_queue
        end

        it 'raises error Queue if no name given' do
          expect { subject.queue }.to raise_error ArgumentError
        end

        it 'does not replace existing queue with the same name' do
          original_queue = mock('original_queue', :name => 'name')
          subject.queues << original_queue
          original_length = subject.queues.length
          new_queue = mock('new_queue', :name => 'name')
          MQ::Queue.should_receive(:new).with(subject, 'name', {}).and_return(new_queue)
          queue = subject.queue 'name'
          subject.queues['name'].should == original_queue
          subject.queues.length.should == original_length
          queue.should == original_queue
        end
      end #queue

      describe '#queue!' do
         it 'adds new Queue into @queues even if Queue with such name is already there' do
           original_queue = mock('original_queue', :name => 'name')
           subject.queues << original_queue
           original_length = subject.queues.length
           new_queue = mock('new_queue', :name => 'name')
           MQ::Queue.should_receive(:new).with(subject, 'name', {}).and_return(new_queue)
           queue = subject.queue! 'name'
           queue.should == new_queue
           subject.queues['name'].should == original_queue
           subject.queues.length.should == original_length + 1
         end

         it 'raises error Queue if no name given' do
           expect { subject.queue! }.to raise_error ArgumentError
         end
       end #queue!

      describe '#direct' do
        it 'creates new :direct Exchange and saves it into @exchanges Hash' do
          mock_exchange = mock('mock_exchange', :name => 'name')
          MQ::Exchange.should_receive(:new).with(subject, :direct, 'name', {}).
              and_return(mock_exchange)
          exchange = subject.direct 'name'
          exchange.should == mock_exchange
          subject.exchanges['name'].should == mock_exchange
        end

        it 'creates "amq.direct" Exchange if no name given' do
          mock_exchange = mock('mock_exchange', :name => 'amq.direct')
          MQ::Exchange.should_receive(:new).with(subject, :direct, 'amq.direct', {}).
              and_return(mock_exchange)
          exchange = subject.direct
          exchange.should == mock_exchange
          subject.exchanges['amq.direct'].should == mock_exchange
        end

        it 'does not replace exchange with existing name' do
          original_exchange = mock('original_exchange', :name => 'name')
          subject.exchanges << original_exchange
          original_length = subject.exchanges.length
          new_exchange = mock('new_exchange', :name => 'name')
          MQ::Exchange.should_receive(:new).with(subject, :direct, 'name', {}).
              and_return(new_exchange)
          exchange = subject.direct 'name'
          subject.exchanges['name'].should == original_exchange
          subject.exchanges.length.should == original_length
          exchange.should == original_exchange
        end
      end #direct

      describe '#fanout' do
        it 'creates new :fanout Exchange and saves it into @exchanges Hash' do
          mock_exchange = mock('mock_exchange', :name => 'name')
          MQ::Exchange.should_receive(:new).with(subject, :fanout, 'name', {}).
              and_return(mock_exchange)
          exchange = subject.fanout 'name'
          exchange.should == mock_exchange
          subject.exchanges['name'].should == mock_exchange
        end

        it 'creates "amq.fanout" Exchange if no name given' do
          mock_exchange = mock('mock_exchange', :name => 'amq.fanout')
          MQ::Exchange.should_receive(:new).with(subject, :fanout, 'amq.fanout', {}).
              and_return(mock_exchange)
          exchange = subject.fanout
          exchange.should == mock_exchange
          subject.exchanges['amq.fanout'].should == mock_exchange
        end

        it 'does not replace exchange with existing name' do
          original_exchange = mock('original_exchange', :name => 'name')
          subject.exchanges << original_exchange
          original_length = subject.exchanges.length
          new_exchange = mock('new_exchange', :name => 'name')
          MQ::Exchange.should_receive(:new).with(subject, :fanout, 'name', {}).
              and_return(new_exchange)
          exchange = subject.fanout 'name'
          subject.exchanges['name'].should == original_exchange
          subject.exchanges.length.should == original_length
          exchange.should == original_exchange
        end
      end #fanout

      describe '#topic' do
        it 'creates new :topic Exchange and saves it into @exchanges Hash' do
          mock_exchange = mock('mock_exchange', :name => 'name')
          MQ::Exchange.should_receive(:new).with(subject, :topic, 'name', {}).
              and_return(mock_exchange)
          exchange = subject.topic 'name'
          exchange.should == mock_exchange
          subject.exchanges['name'].should == mock_exchange
        end

        it 'creates "amq.topic" Exchange if no name given' do
          mock_exchange = mock('mock_exchange', :name => 'amq.topic')
          MQ::Exchange.should_receive(:new).with(subject, :topic, 'amq.topic', {}).
              and_return(mock_exchange)
          exchange = subject.topic
          exchange.should == mock_exchange
          subject.exchanges['amq.topic'].should == mock_exchange
        end

        it 'does not replace exchange with existing name' do
          original_exchange = mock('original_exchange', :name => 'name')
          subject.exchanges << original_exchange
          original_length = subject.exchanges.length
          new_exchange = mock('new_exchange', :name => 'name')
          MQ::Exchange.should_receive(:new).with(subject, :topic, 'name', {}).
              and_return(new_exchange)
          exchange = subject.topic 'name'
          subject.exchanges['name'].should == original_exchange
          subject.exchanges.length.should == original_length
          exchange.should == original_exchange
        end
      end #topic

      describe '#headers' do
        it 'creates new :headers Exchange and saves it into @exchanges Hash' do
          mock_exchange = mock('mock_exchange', :name => 'name')
          MQ::Exchange.should_receive(:new).with(subject, :headers, 'name', {}).
              and_return(mock_exchange)
          exchange = subject.headers 'name'
          exchange.should == mock_exchange
          subject.exchanges['name'].should == mock_exchange
        end

        it 'creates "amq.match" Exchange if no name given' do
          mock_exchange = mock('mock_exchange', :name => 'amq.match')
          MQ::Exchange.should_receive(:new).with(subject, :headers, 'amq.match', {}).
              and_return(mock_exchange)
          exchange = subject.headers
          exchange.should == mock_exchange
          subject.exchanges['amq.match'].should == mock_exchange
        end

        it 'does not replace exchange with existing name' do
          original_exchange = mock('original_exchange', :name => 'name')
          subject.exchanges << original_exchange
          original_length = subject.exchanges.length
          new_exchange = mock('new_exchange', :name => 'name')
          MQ::Exchange.should_receive(:new).with(subject, :headers, 'name', {}).
              and_return(new_exchange)
          exchange = subject.headers 'name'
          subject.exchanges['name'].should == original_exchange
          subject.exchanges.length.should == original_length
          exchange.should == original_exchange
        end
      end #headers
    end # describe 'setting up exchanges/queues/rpcs'

    describe '#process_frame', '(MQ object reaction to messages from broker)' do
      # Some types of Frames are processed directly by Client/Connection,
      # But channel-specific Frames are passed to respective MQ object
      # TODO: these specs are too implementation-dependant, rephrase in terms of behavior?

      describe ' Frame::Header', '(Header received)' do
        before do # process method frame, normally coming before header frame
          subject.consumers['test_consumer'] = @consumer = mock('consumer').as_null_object
          subject.process_frame test_method_deliver
        end

        it 'sets @header to frame payload' do
          subject.process_frame test_header
          header = subject.instance_variable_get(:@header)
          header.klass.should == AMQP::Protocol::Test
          header.size.should == 4
          header.weight.should == 2
          header.properties.should == {:delivery_mode => 1}
        end

        it 'sets @body to ""' do
          subject.process_frame test_header
          subject.instance_variable_get(:@body).should == ''
        end

        it 'does not deliver anything to consumer' do
          @consumer.should_not_receive(:receive)
          subject.process_frame test_header
        end
      end # Frame::Header

      describe ' Frame::Body', '(Body/Data received)' do
        before do # process method and header frames, normally coming before body frame
          subject.consumers['test_consumer'] = @consumer = mock('consumer').as_null_object
          subject.process_frame test_method_deliver
          subject.process_frame test_header
        end

        it 'just adds Frame payload to @body if @body is less than @header.size' do
          @consumer.should_not_receive(:receive)
          subject.process_frame AMQP::Frame::Body.new('da')
          subject.instance_variable_get(:@body).should == 'da'
        end

        context 'if Frame payload exceeds @header size' do

          it 'updates @header with @method.args and passes @header/data to consumer' do
            should_pass_updated_header_and_data_to @consumer, :size => 4, :body => 'data'
            subject.process_frame AMQP::Frame::Body.new('data')
          end

          it 'resets @body, @header, @consumer and @method to nil' do
            subject.process_frame AMQP::Frame::Body.new('data')
            should_be_nil :@body, :@header, :@consumer, :@method
          end
        end # context if Frame payload exceeds @header size

        context 'when @body + Frame payload exceeds @header size' do
          it 'updates @header with @method.args and passes @header/data to consumer' do
            should_pass_updated_header_and_data_to @consumer, :size => 4, :body => 'data'
            subject.process_frame AMQP::Frame::Body.new('da')
            subject.process_frame AMQP::Frame::Body.new('ta')
          end

          it 'resets @body, @header, @consumer and @method to nil' do
            subject.process_frame AMQP::Frame::Body.new('da')
            subject.process_frame AMQP::Frame::Body.new('ta')
            should_be_nil :@body, :@header, :@consumer, :@method
          end
        end # context when @body + Frame payload exceeds @header size
      end # Frame::Body

      describe ' Frame::Method', '(Method with args received)' do

        describe ' Protocol::Channel::OpenOk',
                 '(broker confirmed channel opening)' do
          let(:frame) { AMQP::Frame::Method.new(AMQP::Protocol::Channel::OpenOk.new) }

          it 'sends request to access security realm /data' do
            subject
            @client.should_receive(:send).with do |method, opts|
              method.realm.should == '/data'
              method.should be_an AMQP::Protocol::Access::Request
              opts[:channel].should == 1
            end

            subject.process_frame frame
          end
        end # Protocol::Channel::OpenOk

        describe ' Protocol::Access::RequestOk',
                 '(broker granted access to security realm /data)' do
          let(:frame) { AMQP::Frame::Method.new(AMQP::Protocol::Access::RequestOk.new(
                                                    :ticket => 1313)) }

          it 'sets @ticket (security token received from broker)' +
                 ' - it is later presented to broker where appropriate' do
            subject.process_frame frame
            subject.instance_variable_get(:@ticket).should == 1313
          end

          it 'changes MQ object deferred status to ":succeeded"' do
            subject.set_deferred_status :unknown
            subject.callback { @callback_called = true }

            subject.process_frame frame
            @callback_called.should == true
            subject.instance_variable_get(:@deferred_status).should == :succeeded
          end

          it 'sends request to close channel if @closing' do
            subject_mock(:@closing)
            @client.should_receive(:send).with do |method, opts|
              method.should be_an AMQP::Protocol::Channel::Close
              opts[:channel].should == 1
            end

            subject.process_frame frame
          end
        end # Protocol::Access::RequestOk

        describe ' Protocol::Queue::DeclareOk',
                 '(broker confirms Queue declaration)' do
          let(:frame) { AMQP::Frame::Method.new(AMQP::Protocol::Queue::DeclareOk.new(
                                                    :queue => 'queue',
                                                    :message_count => 0,
                                                    :consumer_count => 0)) }

          it 'sets status for Queue for which declaration was confirmed' do
            queue = subject.queue('queue', :nowait => false)
            queue.should_receive(:receive_status).with(
                instance_of(AMQP::Protocol::Queue::DeclareOk))
            subject.process_frame frame
          end

          it 'does not blow up when we declare Queue with :nowait => true and no block' do
            queue = subject.queue('queue', :nowait => true)
            queue.should_receive(:receive_status).with(
                instance_of(AMQP::Protocol::Queue::DeclareOk))
            subject.process_frame frame
          end

          it 'should report MQ.error if no queue with :unfinished status exists'
          it 'should not depend on received :consumer_tag - wrong for implicit queues'
        end # Protocol::Queue::DeclareOk

        describe ' Protocol::Basic::CancelOk',
                 '(broker confirms cancellation of consumer/subscriber)' do
          let(:frame) { AMQP::Frame::Method.new(AMQP::Protocol::Basic::CancelOk.new(
                                                    :consumer_tag => 'test_consumer')) }

          it 'cancels @consumer matching received :consumer_tag' do
            subject.consumers['test_consumer'] = consumer = mock('consumer')
            consumer.should_receive(:cancelled)
            MQ.should_not_receive(:error)

            subject.process_frame frame
            subject.instance_variable_get(:@consumer).should == consumer
          end

          it 'reports MQ.error if no consumers with received consumer_id' do
            MQ.should_receive(:error).
                with /Basic.CancelOk for invalid consumer tag: test_consumer/
            subject.process_frame frame
          end
        end # Protocol::Basic::CancelOk

        describe ' Protocol::Basic::Deliver',
                 '(broker informs subscriber that data will be delivered shortly)' do
          let(:frame) { test_method_deliver }

          it 'sets @consumer to the one matching received :consumer_tag' do
            subject.consumers['test_consumer'] = consumer = mock('consumer')
            consumer.should_not_receive(:receive)
            MQ.should_not_receive(:error)

            subject.process_frame frame
            subject.instance_variable_get(:@consumer).should == consumer
          end

          it 'prepares @header, @body and @method for upcoming header/body frames' do
            subject.process_frame frame
            subject.instance_variable_get(:@header).should be_nil
            subject.instance_variable_get(:@body).should == ''
            subject.instance_variable_get(:@method).should be_an AMQP::Protocol::Basic::Deliver
          end

          it 'reports MQ.error if no consumers with received consumer_id' do
            MQ.should_receive(:error).
                with /Basic.Deliver for invalid consumer tag: test_consumer/
            subject.process_frame frame
          end
        end # Protocol::Basic::Deliver

        describe ' Protocol::Basic::GetOk',
                 '(broker replied that data is forthcoming, as a response to Basic::Get)' do
          let(:frame) { AMQP::Frame::Method.new(AMQP::Protocol::Basic::GetOk.new) }

          it 'shifts @consumer from get_queue FIFO, but does not send it anything' +
                 ' as actual data is not received yet' do
            consumer = mock('consumer')
            subject.get_queue { |q| q.unshift consumer }
            consumer.should_not_receive(:receive)
            MQ.should_not_receive(:error)

            subject.process_frame frame
            subject.instance_variable_get(:@consumer).should == consumer
            subject.get_queue { |q| q.should be_empty }
          end

          it 'prepares @header, @body and @method for upcoming header/body frames' do
            subject.process_frame frame
            subject.instance_variable_get(:@header).should be_nil
            subject.instance_variable_get(:@body).should == ''
            subject.instance_variable_get(:@method).should be_an AMQP::Protocol::Basic::GetOk
          end

          it 'reports MQ.error if no queues waiting for this response in get_queue FIFO' do
            MQ.should_receive(:error).
                with /No pending Basic.GetOk requests/
            subject.process_frame frame
          end
        end # Protocol::Basic::GetOk

        describe ' Protocol::Basic::GetEmpty',
                 '(broker replied that queue is empty, as a response to Basic::Get)' do
          let(:frame) { AMQP::Frame::Method.new(AMQP::Protocol::Basic::GetEmpty.new) }

          it 'shifts consumer from get_queue FIFO and sends it nil header and body' do
            consumer = mock('consumer')
            subject.get_queue { |q| q.unshift consumer }
            consumer.should_receive(:receive).with(nil, nil)
            MQ.should_not_receive(:error)

            subject.process_frame frame
            subject.get_queue { |q| q.should be_empty }
          end

          it 'reports MQ.error if no queues waiting for this response in get_queue FIFO' do
            MQ.should_receive(:error).
                with /Basic.GetEmpty for invalid consumer/
            subject.process_frame frame
          end
        end # Protocol::Basic::GetEmpty

        describe ' Protocol::Basic::ConsumeOk',
                 '(broker confirmed requested subscription)' do
          let(:frame) { AMQP::Frame::Method.new(AMQP::Protocol::Basic::ConsumeOk.new(
                                                    :consumer_tag => 'zorro')) }

          it 'reports MQ.error if no consumer with given consumer_tag' do
            MQ.should_receive(:error).
                with /Basic.ConsumeOk for invalid consumer tag: zorro/
            subject.process_frame frame
          end

          it 'confirms subscription for consumer with given consumer_tag' do
            zorro = mock 'consumer zorro'
            subject.consumers['zorro'] = zorro
            zorro.should_receive(:confirm_subscribe)
            subject.process_frame frame
          end
        end # Protocol::Basic::ConsumeOk

        describe ' Protocol::Channel::Close',
                 '(broker requested to close channel - unexpectedly!)' do

          it 'raises MQ exception' do
            expect {
              subject.process_frame AMQP::Frame::Method.new(
                                        AMQP::Protocol::Channel::Close.new(
                                            :reply_code => 200,
                                            :reply_text => 'byebye',
                                            :class_id => :test,
                                            :method_id => :content))
            }.to raise_error MQ::Error, /byebye in AMQP::Protocol::Test::Content on 1/
          end
        end # Protocol::Channel::Close

        describe 'Protocol::Channel::CloseOk',
                 '(confirmation of our request to close channel received from broker)' do

          it 'closes the channel down' do
            @client.channels.should_receive(:delete) do |key|
              key.should == 1
              @client.channels.clear
            end
            subject.process_frame AMQP::Frame::Method.new(
                                      AMQP::Protocol::Channel::CloseOk.new)
          end

          it 'closes down connection if no other channels' do
            @client.should_receive(:close)
            subject.process_frame AMQP::Frame::Method.new(
                                      AMQP::Protocol::Channel::CloseOk.new)
          end
        end # Protocol::Channel::CloseOk
      end # Frame::Method
    end #process_frame

  end #  context 'when initialized with a mock connection'
end # describe MQ object, also vaguely known as "channel"